import 'dart:async';
import 'dart:isolate';

import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';

typedef ConnectorParams = (
  SendPort,
  bool, // logTraffic
  bool, // verbose
  String, // loggingTag
);
typedef PortPair = (int, int);

const int isolateStartTimeoutMs = 500;
const int isolateBindPortsTimeoutMs = 1500;

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
        'Received unhandled request $req from main isolate - terminating');
    await stop();
  }
}

/// Wrapper for inter-isolate requests
class IIRequest {
  final int id;
  final String type;
  final dynamic payload;

  IIRequest({
    required this.id,
    required this.type,
    required this.payload,
  });

  factory IIRequest.create(
    String type,
    dynamic payload,
  ) =>
      IIRequest(
        id: DateTime.now().microsecondsSinceEpoch,
        type: type,
        payload: payload,
      );

  @override
  String toString() {
    return 'IIRequest{id: $id, type: $type, payload: $payload}';
  }
}

/// Wrapper for responses to inter-isolate requests
class IIResponse {
  final int id;
  final bool isError;
  final dynamic payload;

  IIResponse({
    required this.id,
    required this.isError,
    required this.payload,
  });

  @override
  String toString() {
    return 'IIResponse{id: $id, isError: $isError, payload: $payload}';
  }
}
