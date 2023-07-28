import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final SSHNPD sshnpd;

  try {
    sshnpd = await SSHNPD.fromCommandLineArgs(args);
  } on ArgumentError catch (_) {
    exit(1);
  }

  await runZonedGuarded(() async {
    await sshnpd.init();
    await sshnpd.run();
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
