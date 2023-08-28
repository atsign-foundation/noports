// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/utils.dart';

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
    await cleanUpAfterReverseSsh(sshnp);
    exit(1);
  });

  await runZonedGuarded(() async {
    if (params.listDevices) {
      print('Searching for devices...');
      var (active, off, info) = await sshnp.listDevices();
      if (active.isEmpty && off.isEmpty) {
        print('[X] No devices found\n');
        print(
            'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command.');
        print(
            'Please update your devices to sshnpd version >= 3.4.0 and try again.');
        exit(0);
      }

      print('Active Devices:');
      _printDevices(active, info);
      print('Inactive Devices:');
      _printDevices(off, info);
      exit(0);
    }

    await sshnp.init();
    SSHNPResult res = await sshnp.run();
    if (res is SSHNPFailed) {
      exit(1);
    }
    if (res is SSHCommand) {
      stdout.write('$res\n');
    }
    exit(0);
  }, (Object error, StackTrace stackTrace) async {
    stderr.writeln(error.toString());

    if (params.verbose) {
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    }

    await cleanUpAfterReverseSsh(sshnp);

    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  });
}

void _printDevices(Iterable<String> devices, Map<String, dynamic> info) {
  if (devices.isEmpty) {
    print('  [X] No devices found');
    return;
  }
  for (var device in devices) {
    print('  $device - v${info[device]?['version']}');
  }
}
