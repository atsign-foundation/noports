// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/sshnp/params/sshnp_params.dart';

// local packages
import 'package:noports_core/sshnp/sshnp.dart';
import 'package:noports_core/sshnp/utils.dart';
import 'package:sshnoports/create_at_client_cli.dart';
import 'package:sshnoports/version.dart';

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
    sshnp = await SSHNP.fromParams(
      params,
      atClientGenerator: (SSHNPParams params, String sessionId) =>
          createAtClientCli(
        homeDirectory: params.homeDirectory,
        atsign: params.clientAtSign!,
        namespace: '${params.device}.sshnp',
        pathExtension: sessionId,
        atKeysFilePath: params.atKeysFilePath,
        rootDomain: params.rootDomain,
      ),
      usageCallback: (e, s) {
        printVersion();
        stdout.writeln(SSHNPPartialParams.parser.usage);
        stderr.writeln('\n$e');
      },
    );
  } on ArgumentError catch (_) {
    exit(1);
  }

  ProcessSignal.sigint.watch().listen((signal) async {
    await cleanUpAfterReverseSsh(sshnp);
    exit(1);
  });

  await runZonedGuarded(() async {
    if (params.listDevices) {
      stdout.writeln('Searching for devices...');
      var (active, off, info) = await sshnp.listDevices();
      if (active.isEmpty && off.isEmpty) {
        stdout.writeln('[X] No devices found\n');
        stdout.writeln(
            'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command.');
        stdout.writeln(
            'Please update your devices to sshnpd version >= 3.4.0 and try again.');
        exit(0);
      }

      stdout.writeln('Active Devices:');
      _printDevices(active, info);
      stdout.writeln('Inactive Devices:');
      _printDevices(off, info);
      exit(0);
    }

    await sshnp.init();
    SSHNPResult res = await sshnp.run();
    if (res is SSHNPFailed) {
      stderr.write('$res\n');
      exit(1);
    }
    if (res is SSHNPSuccess) {
      stdout.write('$res\n');
      await sshnp.done;
      exit(0);
    }
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
    stdout.writeln('  [X] No devices found');
    return;
  }
  for (var device in devices) {
    stdout.writeln('  $device - v${info[device]?['version']}');
  }
}
