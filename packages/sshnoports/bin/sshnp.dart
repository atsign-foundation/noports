// dart packages
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
  SSHNP? sshnp;
  SSHNPParams? params;

  try {
    params = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgs(args));
  } catch (error) {
    stderr.writeln(error.toString());
    exit(1);
  }

  try {
    sshnp = await SSHNP.fromParams(params);

    ProcessSignal.sigint.watch().listen((signal) async {
      await cleanUp(sshnp!.sessionId, sshnp.logger);
      exit(1);
    });

    if (params.listDevices) {
      var (active, off, info) = await sshnp.listDevices();
      if (active.isEmpty && off.isEmpty) {
        print('No devices found\n');
        print(
            'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command');
        print(
            'Please update your devices to sshnpd version >= 3.4.0 and try again');
        exit(0);
      }
      if (active.isNotEmpty) {
        print('Active Devices:');
        for (var device in active) {
          print('  $device - ${info[device]['version']}');
        }
      }
      if (off.isNotEmpty) {
        print('Inactive Devices:');
        for (var device in off) {
          print('  $device - ${info[device]['version']}');
        }
      }
      exit(0);
    }

    await sshnp.init();
    await sshnp.run();
    exit(0);
  } on ArgumentError catch (_) {
    exit(1);
  } catch (error, stackTrace) {
    stderr.writeln(error.toString());

    if (params.verbose) {
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    }

    if (sshnp != null) {
      await cleanUp(sshnp.sessionId, sshnp.logger);
    }

    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
