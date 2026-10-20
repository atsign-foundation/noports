import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/src/events/noports_event_types.dart';

final AtSignLogger _logger = AtSignLogger('NPAImpl');

class NPAImpl
    with AtClientBindings, AtEventLogger, AtEventListener
    implements NPA {
  @override
  final AtSignLogger logger = _logger;

  @override
  late AtClient atClient;

  @override
  final String homeDirectory;

  @override
  Atsign get policyAtsign => atClient.getCurrentAtSign()!.toAtsign();

  @override
  final Atsign? eventLoggingAtsign;

  AtEventConfig? elc;

  final Set<String> _sharedElcWith = {};

  @override
  final NPARequestHandler handler;

  NPAImpl({
    // final fields
    required this.atClient,
    required this.homeDirectory,
    required this.handler,
    required this.eventLoggingAtsign,
  }) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<NPA> fromCommandLineArgs(
    List<String> args, {
    required NPARequestHandler handler,
    AtClient? atClient,
    FutureOr<AtClient> Function(NPAParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
  }) async {
    try {
      final NPAParams p;
      try {
        p = await NPAParams.fromArgs(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      // Check atKeyFile selected exists
      if (!await File(p.atKeysFilePath).exists()) {
        throw ArgumentError('Unable to find .atKeys file: ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      var sshnpa = NPAImpl(
        atClient: atClient,
        homeDirectory: p.homeDirectory,
        handler: handler,
        eventLoggingAtsign: p.eventLoggingAtsign?.toAtsign(),
      );

      if (p.verbose) {
        sshnpa.logger.logger.level = Level.INFO;
      }

      return sshnpa;
    } on ArgumentError catch (e, s) {
      usageCallback?.call(e, s);
      rethrow;
    }
  }

  @override
  Future<void> run() async {
    if (eventLoggingAtsign != null) {
      try {
        elc = await getEventLoggingConfig(
          atSign: eventLoggingAtsign!,
          namespace: DefaultArgs.eventLoggingNamespace,
        );
      } catch (e) {
        throw EventLoggingConfigException(eventLoggingAtsign!, e);
      }
      logger.shout(
        'Fetched AtEventLogger config $elc from $eventLoggingAtsign',
      );
    }

    _startPolicyInfoRpcServer();

    subscribe(regex: r'.*\.devices\.policy\.sshnp', shouldDecrypt: true).listen(
      (AtNotification n) async {
        if (n.value == null) return;

        if (elc != null &&
            !_sharedElcWith.contains(n.from) &&
            handler.hasRulesFor(n.from.toAtsign())) {
          try {
            logger.info('Sharing event logging config with ${n.from}');
            await shareEventLoggingConfigWithAtsigns(
              config: elc!,
              atSigns: [n.from.toAtsign()],
              namespace: DefaultArgs.eventLoggingNamespace,
            );
            _sharedElcWith.add(n.from);
          } catch (e) {
            logger.warning(
              'Failed to share event logging config with ${n.from}: $e',
            );
          }
        }
      },
    );
  }

  late final AtRpc _policyInfoRpcServer;

  void _startPolicyInfoRpcServer() {
    _policyInfoRpcServer = AtRpc(
      atClient: atClient,
      baseNameSpace: DefaultArgs.namespace,
      domainNameSpace: 'auth_checks',
      callbacks: PolicyInfoRpcRequestHandler(
        policyAtsign: policyAtsign,
        namespace: DefaultArgs.namespace,
        handler: handler,
        atClient: atClient,
        onEvent: (event) async {
          if (elc != null) await logEvent(elc!, event);
        },
      ),
      allowList: _DaemonsWithRules(handler),
      allowAll: false,
      isClient: false,
      isServer: true,
      enableRequestMutex: true,
    );

    _policyInfoRpcServer.start();

    logger.info(
      'Listening for requests at'
      ' ${_policyInfoRpcServer.domainNameSpace}'
      '.${_policyInfoRpcServer.rpcsNameSpace}'
      '.${_policyInfoRpcServer.baseNameSpace}',
    );
  }
}

class PolicyInfoRpcRequestHandler
    with AtClientBindings
    implements AtRpcCallbacks {
  @override
  final AtClient atClient;
  @override
  final AtSignLogger logger = AtSignLogger('PolicyInfoRpcRequestHandler');

  final Atsign policyAtsign;
  final String namespace;
  final NPARequestHandler handler;

  /// Receives each policy event.
  final Future<void> Function(Map<String, dynamic> event) onEvent;

  PolicyInfoRpcRequestHandler({
    required this.policyAtsign,
    required this.namespace,
    required this.handler,
    required this.atClient,
    required this.onEvent,
  });

  /// Builds an event with [build] and hands it to [onEvent]. A failure in
  /// either is logged and swallowed: the event log must never change the
  /// answer a daemon gets.
  Future<void> _sendEvent(Map<String, dynamic> Function() build) async {
    try {
      await onEvent(build());
    } catch (e) {
      logger.warning('Failed to log policy event: $e');
    }
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.info(
      'Received request from $fromAtSign: '
      '${jsonPrettyPrinter.convert(request.toJson())}',
    );

    NPAAuthCheckRequest authCheckRequest = NPAAuthCheckRequest.fromJson(
      request.payload,
    );
    final Atsign sender = fromAtSign.toAtsign();
    final bool aboutItself = sender == authCheckRequest.daemonAtsign.toAtsign();
    NPAAuthCheckResponse answer;
    String? failure;
    if (!aboutItself) {
      logger.warning(
        'Refusing a check from $fromAtSign'
        ' about ${authCheckRequest.daemonAtsign}',
      );
      answer = NPAAuthCheckResponse(
        authorized: false,
        message: 'A daemon may ask only about itself',
        permitOpen: [],
      );
    } else {
      try {
        answer = await handler.doAuthCheck(authCheckRequest);
      } catch (e, st) {
        logger.shout('Exception: $e : StackTrace : \n$st');
        failure = '$e';
        answer = NPAAuthCheckResponse(
          authorized: false,
          message: 'Exception: $e',
          permitOpen: [],
        );
      }
    }
    final AtRpcResp rpcResponse = AtRpcResp(
      reqId: request.reqId,
      respType: AtRpcRespType.success,
      payload: answer.toJson(),
    );

    // The answer is settled before the event is built, so building or
    // sending the event can never change it.
    await _sendEvent(() {
      final String? error = failure;
      if (!aboutItself) {
        return PolicyEvent.requestRefused(
          policyAtsign: policyAtsign,
          fromAtsign: sender,
          request: authCheckRequest,
          response: answer,
        );
      } else if (error != null) {
        return PolicyEvent.policyCheckFailed(
          policyAtsign: policyAtsign,
          fromAtsign: sender,
          request: authCheckRequest,
          error: error,
        );
      } else if (answer.authorized) {
        return PolicyEvent.clientAdmitted(
          policyAtsign: policyAtsign,
          fromAtsign: sender,
          request: authCheckRequest,
          response: answer,
        );
      } else {
        return PolicyEvent.clientRejected(
          policyAtsign: policyAtsign,
          fromAtsign: sender,
          request: authCheckRequest,
          response: answer,
        );
      }
    });

    // We will send a 'log' notification to ourselves
    var logKey = AtKey()
      ..key = '${DateTime.now().millisecondsSinceEpoch}.logs.policy'
      ..sharedBy = policyAtsign
      ..sharedWith = policyAtsign
      ..namespace = namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true);
    await notify(
      logKey,
      jsonEncode({
        'daemon': fromAtSign,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': {'request': request, 'response': rpcResponse},
      }),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(hours: 1),
    );
    return rpcResponse;
  }

  /// We're not sending any RPCs so we don't implement `handleResponse`
  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError();
  }
}

/// The daemons [handler] has rules for, as the allow list [AtRpc] checks each
/// request's sender against; it answers only whether it holds an atSign.
class _DaemonsWithRules extends SetBase<String> {
  _DaemonsWithRules(this.handler);

  final NPARequestHandler handler;

  @override
  bool contains(Object? element) {
    final atSign = element is String ? canonicalAtsign(element) : null;
    return atSign != null && handler.hasRulesFor(atSign);
  }

  @override
  String? lookup(Object? element) =>
      contains(element) ? element as String : null;

  @override
  Iterator<String> get iterator =>
      throw UnsupportedError('The daemons with rules are not listed');

  @override
  int get length =>
      throw UnsupportedError('The daemons with rules are not counted');

  @override
  bool add(String value) =>
      throw UnsupportedError('The daemons with rules come from the rules');

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('The daemons with rules come from the rules');

  @override
  Set<String> toSet() =>
      throw UnsupportedError('The daemons with rules are not listed');

  @override
  String toString() => 'daemons with policy rules';
}
