// dart packages
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/cleanup.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  SSHNP? sshnp;
  try {
    sshnp = await SSHNP.fromCommandLineArgs(args);

    ProcessSignal.sigint.watch().listen((signal) async {
      await cleanUp(sshnp!.sessionId, sshnp.logger);
      exit(1);
    });

    await sshnp.init();
    await sshnp.run();
    exit(0);
  } catch (error, stackTrace) {
    stderr.writeln("\n${error.toString()}");

    if (sshnp?.verbose ?? false) {
      /// only show stack trace if verbose is true
      /// or if the program failed before it could be set
      stderr.writeln('\nStack Trace: $stackTrace');
    }

    if (sshnp != null) {
      await cleanUp(sshnp.sessionId, sshnp.logger);
    }
    exit(1);
  }
}
