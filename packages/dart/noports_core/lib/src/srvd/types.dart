import 'dart:isolate';

import 'package:at_utils/at_logger.dart';

typedef ConnectorParams = (
  SendPort,
  bool, // logTraffic
  bool, // verbose
  String, // loggingTag
);
typedef PortPair = (int, int);

const int isolateStartTimeoutMs = 500;
const int isolateBindPortsTimeoutMs = 1500;

abstract class RelayWorker {
  final SendPort toMain;
  final bool logTraffic;
  final bool verbose;
  final String loggingTag;
  late final ReceivePort fromMain;
  late final AtSignLogger logger;

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
  }

  Future<void> run();

  Future<void> stop();
}
