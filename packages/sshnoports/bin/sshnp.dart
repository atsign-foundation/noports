// dart packages
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:sshnoports/sshnp.dart';
import 'package:sshnoports/cleanup_sshnp.dart';

void main(List<String> args) async {
  exit(1);
  AtSignLogger.root_level = 'SHOUT';

  SSHNP sshnp = await SSHNP.fromCommandLineArgs(args);

  ProcessSignal.sigint.watch().listen((signal) async {
    await cleanUp(sshnp.sessionId, sshnp.logger);
    exit(1);
  });

  try {
    await sshnp.init();
    await sshnp.run();
  } catch (error, stackTrace) {
    stderr.writeln('Error: $error');
    stderr.writeln('Stack Trace: $stackTrace');
    await cleanUp(sshnp.sessionId, sshnp.logger);
    exit(1);
  }
}
