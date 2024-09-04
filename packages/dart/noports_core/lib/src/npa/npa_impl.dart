import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/utils.dart';

class NPAImpl with AtClientBindings implements NPA {
  @override
  final AtSignLogger logger = AtSignLogger(' sshnpa ');

  @override
  late AtClient atClient;

  @override
  final String homeDirectory;

  @override
  String get authorizerAtsign => atClient.getCurrentAtSign()!;

  @override
  String get loggingAtsign => atClient.getCurrentAtSign()!;

  @override
  final Set<String> daemonAtsigns;

  @override
  final NPARequestHandler handler;

  static const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

  NPAImpl({
    // final fields
    required this.atClient,
    required this.homeDirectory,
    required this.daemonAtsigns,
    required this.handler,
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

      var sshnpa = NPAImpl(
        atClient: atClient,
        homeDirectory: p.homeDirectory,
        daemonAtsigns: daemonAtsigns ?? p.daemonAtsigns,
        handler: handler,
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
    AtRpc rpc = AtRpc(
        atClient: atClient,
        baseNameSpace: DefaultArgs.namespace,
        domainNameSpace: 'auth_checks',
        callbacks: this,
        allowList: daemonAtsigns);

    rpc.start();

    logger.info('Listening for requests at '
        '${rpc.domainNameSpace}.${rpc.rpcsNameSpace}.${rpc.baseNameSpace}');
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.info('Received request from $fromAtSign: '
        '${jsonPrettyPrinter.convert(request.toJson())}');
    // We will send a 'log' notification to the loggingAtsign
    var logKey = AtKey()
      ..key = '${DateTime.now().millisecondsSinceEpoch}.logs.policy'
      ..sharedBy = authorizerAtsign
      ..sharedWith = loggingAtsign
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true);

    NPAAuthCheckRequest authCheckRequest =
        NPAAuthCheckRequest.fromJson(request.payload);
    AtRpcResp rpcResponse;
    try {
      var authCheckResponse = await handler.doAuthCheck(authCheckRequest);
      rpcResponse = AtRpcResp(
          reqId: request.reqId,
          respType: AtRpcRespType.success,
          payload: authCheckResponse.toJson());
    } catch (e, st) {
      logger.shout('Exception: $e : StackTrace : \n$st');
      rpcResponse = AtRpcResp(
          reqId: request.reqId,
          respType: AtRpcRespType.success,
          payload: NPAAuthCheckResponse(
            authorized: false,
            message: 'Exception: $e',
            permitOpen: [],
          ).toJson());
    }
    await notify(
      logKey,
      // TODO Make a PolicyLogEvent and use PolicyLogEvent.toJson()
      jsonEncode(
        {
          'daemon': fromAtSign,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'request': request,
          'response': rpcResponse
        },
      ),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(hours: 1),
    );
    return rpcResponse;
  }

  /// We're not sending any RPCs so we don't implement `handleResponse`
  @override
  Future<void> handleResponse(AtRpcResp response) {
    // TODO: implement handleResponse
    throw UnimplementedError();
  }
}
