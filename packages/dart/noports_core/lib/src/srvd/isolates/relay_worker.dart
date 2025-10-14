import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';

typedef RelayWorkerRequestHandler = Future<dynamic> Function(IIRequest);

abstract class RelayWorker implements RelayAuthVerifyHelper {
  final SendPort toMain;
  final bool logTraffic;
  final bool verbose;
  final String loggingTag;
  late final ReceivePort fromMain;
  late final AtSignLogger logger;
  final Map<String, RelayWorkerRequestHandler> reqHandlers = {};
  final Map<int, Completer<IIResponse>> rpcCompleters = {};

  RelayWorker({
    required this.toMain,
    required this.logTraffic,
    required this.verbose,
    required this.loggingTag,
  }) {
    AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
    AtSignLogger.root_level = verbose ? 'INFO' : 'WARNING';
    logger = AtSignLogger(' srvd / $runtimeType / $loggingTag ');

    // Make a ReceivePort so the main isolate can send messages to us
    // and send it to the main isolate
    fromMain = ReceivePort(loggingTag);
    toMain.send(fromMain.sendPort);

    startListening();
  }

  Future<void> stop([IIRequest? req]);

  Future<void> run();

  @nonVirtual
  void startListening() {
    fromMain.listen((msg) async {
      if (msg is IIRequest) {
        final Function handler = reqHandlers[msg.type] ?? unhandledRequest;
        await handler(msg);
      } else if (msg is IIResponse) {
        if (rpcCompleters.containsKey(msg.id)) {
          if (msg.isError) {
            rpcCompleters[msg.id]!.completeError(msg.payload);
          } else {
            rpcCompleters[msg.id]!.complete(msg);
          }
        } else {
          logger.shout('Got an unexpected IIResponse (${msg.toString()})');
        }
        return;
      } else {
        logger.shout('Unhandled message $msg from main isolate - exiting');
        await stop();
      }
    });
  }

  Future<IIResponse> rpcToMain(IIRequest req) async {
    Completer<IIResponse> completer = Completer<IIResponse>();
    rpcCompleters[req.id] = completer;

    toMain.send(req);

    return completer.future;
  }

  Future<void> unhandledRequest(IIRequest req) async {
    logger.shout(
      'Received unhandled request $req from main isolate - terminating',
    );
    await stop();
  }

  Future<(RelayAuthVerifier?, RelayAuthVerifier?)> createAuthVerifiers(
    SrvdSessionParams params,
  ) async {
    switch (params.relayAuthMode) {
      case RelayAuthMode.payload:
        return await createPayloadAuthVerifiers(params);
      case RelayAuthMode.escr:
        return await createEscrAuthVerifiers(params);
    }
  }

  Future<(RelayAuthVerifier?, RelayAuthVerifier?)> createPayloadAuthVerifiers(
    SrvdSessionParams params,
  ) async {
    RelayAuthVerifier? authVerifierA;
    RelayAuthVerifier? authVerifierB;

    Map expectedPayloadForSignature = {
      'sessionId': params.sessionId,
      'clientNonce': params.clientNonce,
      'rvdNonce': params.rvdNonce,
    };

    if (params.authenticateSocketA) {
      String? pkAtSignA = params.publicKeyA ??
          (await rpcToMain(
            IIRequest.create('lookup', 'public:publickey${params.atSignA}'),
          ))
              .payload;
      if (pkAtSignA == null) {
        logger.shout(
          'Cannot spawn socket connector.'
          ' Authenticator for ${params.atSignA}'
          ' could not be created as PublicKey could not be'
          ' fetched from the atServer.',
        );
        throw Exception(
          'Failed to create SocketAuthenticator'
          ' for ${params.atSignA} due to failure to get public key for ${params.atSignA}',
        );
      }
      authVerifierA = RelayAuthVerifierLegacy(
        pkAtSignA,
        jsonEncode(expectedPayloadForSignature),
        params.rvdNonce!,
        params.atSignA!,
        params.atSignA!,
        params.sessionId,
      );
    }

    if (params.authenticateSocketB) {
      String? pkAtSignB = params.publicKeyB ??
          (await rpcToMain(
            IIRequest.create('lookup', 'public:publickey${params.atSignB}'),
          ))
              .payload;
      if (pkAtSignB == null) {
        logger.shout(
          'Cannot spawn socket connector.'
          ' Authenticator for ${params.atSignB}'
          ' could not be created as PublicKey could not be'
          ' fetched from the atServer',
        );
        throw Exception(
          'Failed to create SocketAuthenticator'
          ' for ${params.atSignB} due to failure to get public key for ${params.atSignB}',
        );
      }
      authVerifierB = RelayAuthVerifierLegacy(
        pkAtSignB,
        jsonEncode(expectedPayloadForSignature),
        params.rvdNonce!,
        params.atSignB!,
        params.atSignB!,
        params.sessionId,
      );
    }

    return (authVerifierA, authVerifierB);
  }

  Future<(RelayAuthVerifier?, RelayAuthVerifier?)> createEscrAuthVerifiers(
    SrvdSessionParams params,
  ) async {
    RelayAuthVerifierESCR? authVerifierA;
    RelayAuthVerifierESCR? authVerifierB;

    if (params.authenticateSocketA) {
      authVerifierA = RelayAuthVerifierESCR('${params.sessionId} sideA', this);
    }

    if (params.authenticateSocketB) {
      authVerifierB = RelayAuthVerifierESCR('${params.sessionId} sideB', this);
    }

    return (authVerifierA, authVerifierB);
  }
}
