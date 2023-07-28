// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/cleanup.dart';
import 'package:sshnoports/sshnp/sshnp_params.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;
  late final SSHNP sshnp;
  late final SSHNPParams params;

  try {
    params = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgs(args));
  } catch (error) {
    stderr.writeln(error.toString());
    exit(1);
  }

  try {
    sshnp = await SSHNP.fromParams(params);
  } on ArgumentError catch (_) {
    exit(1);
  }

  ProcessSignal.sigint.watch().listen((signal) async {
    await cleanUp(sshnp.sessionId, sshnp.logger);
    exit(1);
  });

  await runZonedGuarded(() async {
    await sshnp.init();
    await sshnp.run();
    exit(0);
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln(error.toString());

    if (params.verbose) {
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    }

    await cleanUp(sshnp.sessionId, sshnp.logger);

    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}
