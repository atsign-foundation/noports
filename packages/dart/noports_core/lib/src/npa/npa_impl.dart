import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/events.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';

final AtSignLogger _logger = AtSignLogger('NPAImpl');

class NPAImpl with AtClientBindings, AtEventLogger implements NPA {
  @override
  final AtSignLogger logger = _logger;

  @override
  late AtClient atClient;

  @override
  final String homeDirectory;

  @override
  String get policyAtsign => atClient.getCurrentAtSign()!;

  @override
  final Set<String> daemonAtsigns;

  @override
  final NPARequestHandler handler;

  final AtEventLoggingConfig? elc;

  NPAImpl({
    // final fields
    required this.atClient,
    required this.homeDirectory,
    required this.daemonAtsigns,
    required this.handler,
    required this.elc,
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
    Set<String>? daemonAtsigns,
  }) async {
    try {
      var p = await NPAParams.fromArgs(args);

      // Check atKeyFile selected exists
      if (!await File(p.atKeysFilePath).exists()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      AtEventLoggingConfig? elc;
      if (p.eventLoggingAtsign != null) {
        elc = await AtEventLogger.staticGetEventLoggingConfig(
          atClient: atClient,
          atSign: p.eventLoggingAtsign!,
          namespace: DefaultArgs.eventLoggingNamespace,
        );
      }
      var sshnpa = NPAImpl(
        atClient: atClient,
        homeDirectory: p.homeDirectory,
        daemonAtsigns: daemonAtsigns ?? p.daemonAtsigns,
        handler: handler,
        elc: elc,
      );

      if (p.verbose) {
        sshnpa.logger.logger.level = Level.INFO;
      }

      return sshnpa;
    } catch (e, s) {
      usageCallback?.call(e, s);
      rethrow;
    }
  }

  @override
  Future<void> run() async {
    _startPolicyInfoRpcServer();

    subscribe(regex: r'.*\.devices\.policy\.sshnp', shouldDecrypt: true).listen(
      (AtNotification n) async {
        final v = jsonDecode(n.value!);
        final e = {};
        e['timestamp'] = n.epochMillis;
        e['daemon'] = n.from;
        e['payload'] = v;
        String strippedKey = n.key
            .replaceAll('${n.to}:', '')
            .replaceAll(n.from, '')
            .toLowerCase();

        final configKey = AtKey.fromString(
          '${n.from}:config.$strippedKey${n.to}',
        );
        final configValue = jsonEncode({'eventLoggingConfig': elc?.toJson()});
        logger.shout('Sending config notification $configKey : $configValue');
        await notify(
          configKey,
          configValue,
          checkForFinalDeliveryStatus: false,
          waitForFinalDeliveryStatus: false,
          ttln: Duration(hours: 1),
        );
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
        elc: elc,
      ),
      allowList: daemonAtsigns,
      allowAll: true,
      isClient: false,
      isServer: true,
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
  final AtEventLoggingConfig? elc;
  final String namespace;
  final NPARequestHandler handler;

  PolicyInfoRpcRequestHandler({
    required this.policyAtsign,
    required this.namespace,
    required this.handler,
    required this.atClient,
    required this.elc,
  });

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.info(
      'Received request from $fromAtSign: '
      '${jsonPrettyPrinter.convert(request.toJson())}',
    );

    NPAAuthCheckRequest authCheckRequest = NPAAuthCheckRequest.fromJson(
      request.payload,
    );
    AtRpcResp rpcResponse;
    try {
      var authCheckResponse = await handler.doAuthCheck(authCheckRequest);
      rpcResponse = AtRpcResp(
        reqId: request.reqId,
        respType: AtRpcRespType.success,
        payload: authCheckResponse.toJson(),
      );
    } catch (e, st) {
      logger.shout('Exception: $e : StackTrace : \n$st');
      rpcResponse = AtRpcResp(
        reqId: request.reqId,
        respType: AtRpcRespType.success,
        payload: NPAAuthCheckResponse(
          authorized: false,
          message: 'Exception: $e',
          permitOpen: [],
        ).toJson(),
      );
    }
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
