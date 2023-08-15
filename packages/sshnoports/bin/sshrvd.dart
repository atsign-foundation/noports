import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/sshrvd/sshrvd.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final SSHRVD sshrvd;

  try {
    sshrvd = await SSHRVD.fromCommandLineArgs(args);
  } on ArgumentError catch (_) {
    exit(1);
  }

  await runZonedGuarded(() async {
    await sshrvd.init();
    await sshrvd.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
