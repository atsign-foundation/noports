// dart packages
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:sshnoports/sshnp.dart';
import 'package:sshnoports/cleanup_sshnp.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';

  SSHNP sshnp = await SSHNP.fromCommandLineArgs(args);

  ProcessSignal.sigint.watch().listen((signal) async {
    await cleanUp(sshnp.sessionId, sshnp.logger);
    exit(1);
  });

  await sshnp.init();

  await sshnp.run();
}
