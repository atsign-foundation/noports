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
  } on ArgumentError catch (_) {
    exit(1);
  } catch (error, stackTrace) {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');

    if (sshnp != null) {
      await cleanUp(sshnp.sessionId, sshnp.logger);
    }

    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
