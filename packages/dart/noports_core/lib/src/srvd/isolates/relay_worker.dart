import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';

typedef RelayWorkerRequestHandler = Future<dynamic> Function(IIRequest);

abstract class RelayWorker implements RelayAuthVerifyHelper {
  final SendPort toMain;
  final bool logTraffic;
  final bool verbose;
  final String loggingTag;

  /// Window used by [RelayAuthVerifierAuto] to distinguish a legacy connecting
  /// side (which speaks first) from an ESCR one (which waits to be challenged).
  final int relayAuthDetectWindowMs;

  late final ReceivePort fromMain;
  late final AtSignLogger logger;
  final Map<String, RelayWorkerRequestHandler> reqHandlers = {};
  final Map<int, Completer<IIResponse>> rpcCompleters = {};

  RelayWorker({
    required this.toMain,
    required this.logTraffic,
    required this.verbose,
    required this.loggingTag,
    this.relayAuthDetectWindowMs = defaultRelayAuthDetectWindowMs,
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

  /// Tells the main isolate that a socket of session [sessionId] was accepted
  /// with a signature from the `_apsk` record [signingKeyUri].
  void reportSigningKey(String sessionId, String signingKeyUri) =>
      toMain.send(
        IIRequest.create('signingKey', {
          'sessionId': sessionId,
          'key': signingKeyUri,
        }),
      );

  Future<void> unhandledRequest(IIRequest req) async {
    logger.shout(
      'Received unhandled request $req from main isolate - terminating',
    );
    await stop();
  }

  /// Builds a per-socket auto-detecting verifier for each authenticated side.
  ///
  /// Both sides are left to auto-detect: the client declares the universally-
  /// safe legacy mode in `request_ports` (so a relay that does NOT auto-detect
  /// applies one mode both sides can do), and it decides its *actual* per-side
  /// mode only after learning this relay auto-detects — so `params.relayAuthMode`
  /// no longer reflects either side's real mode and must not be used as a
  /// `knownMode` here. Once the client has resolved the modes it sends a
  /// definitive auth-modes notification, which the worker feeds to each verifier
  /// via [setKnownMode] to skip the detection window.
  ///
  /// A legacy socket needs the connecting atSign's public key. The request
  /// handler fetches it up front (`publicKeyA/B`) whenever the request
  /// declares the legacy mode, as clients do by default; when the request
  /// declares ESCR, the auto verifier looks it up only if the socket turns out
  /// to be legacy.
  Future<(RelayAuthVerifierAuto?, RelayAuthVerifierAuto?)> createAuthVerifiers(
    SrvdSessionParams params,
  ) async {
    final String dataToVerify = jsonEncode({
      'sessionId': params.sessionId,
      'clientNonce': params.clientNonce,
      'rvdNonce': params.rvdNonce,
    });

    RelayAuthVerifierAuto? authVerifierA;
    RelayAuthVerifierAuto? authVerifierB;

    if (params.authenticateSocketA) {
      authVerifierA = RelayAuthVerifierAuto(
        '${params.sessionId} sideA',
        this,
        atSign: params.atSignA,
        sessionId: params.sessionId,
        isSideA: true,
        dataToVerify: dataToVerify,
        rvdNonce: params.rvdNonce,
        publicKey: params.publicKeyA,
        detectWindow: Duration(milliseconds: relayAuthDetectWindowMs),
        onEscrVerified: (key) => reportSigningKey(params.sessionId, key),
      );
    }

    if (params.authenticateSocketB) {
      authVerifierB = RelayAuthVerifierAuto(
        '${params.sessionId} sideB',
        this,
        atSign: params.atSignB,
        sessionId: params.sessionId,
        isSideA: false,
        dataToVerify: dataToVerify,
        rvdNonce: params.rvdNonce,
        publicKey: params.publicKeyB,
        detectWindow: Duration(milliseconds: relayAuthDetectWindowMs),
        onEscrVerified: (key) => reportSigningKey(params.sessionId, key),
      );
    }

    return (authVerifierA, authVerifierB);
  }
}
