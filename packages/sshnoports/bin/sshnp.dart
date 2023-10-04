// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshnp_params.dart' show SSHNPArg;
import 'package:noports_core/utils.dart';
import 'package:sshnoports/create_at_client_cli.dart';
import 'package:sshnoports/version.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  late final SSHNPParams params;
  SSHNP? sshnp;

  // Manually check if the verbose flag is set
  Set<String> verboseSet = SSHNPArg.fromName('verbose').aliasList.toSet();
  final bool verbose = args.toSet().intersection(verboseSet).isNotEmpty;

  // Manually check if the help flag is set
  Set<String> helpSet = SSHNPArg.fromName('help').aliasList.toSet();
  final bool help = args.toSet().intersection(helpSet).isNotEmpty;

  if (help) {
    printVersion();
    stderr.writeln(SSHNPPartialParams.parser.usage);
    exit(0);
  }

  await runZonedGuarded(() async {
    try {
      params = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgList(args));
      String homeDirectory = getHomeDirectory()!;
      sshnp = await SSHNP
          .fromParams(
        params,
        atClientGenerator: (SSHNPParams params, String sessionId) =>
            createAtClientCli(
          homeDirectory: homeDirectory,
          atsign: params.clientAtSign,
          namespace: '${params.device}.sshnp',
          pathExtension: sessionId,
          atKeysFilePath: params.atKeysFilePath ??
              getDefaultAtKeysFilePath(homeDirectory, params.clientAtSign),
          rootDomain: params.rootDomain,
        ),
      )
          .catchError((e) {
        if (e.stackTrace != null) {
          Error.throwWithStackTrace(e, e.stackTrace!);
        }
        throw e;
      });

      if (params.listDevices) {
        stderr.writeln('Searching for devices...');
        var (active, off, info) = await sshnp!.listDevices();
        printDevices(active, off, info);
        exit(0);
      }

      await sshnp!.initialized;

      SSHNPResult res = await sshnp!.run();

      if (res is SSHNPError) {
        if (res.stackTrace != null) {
          Error.throwWithStackTrace(res, res.stackTrace!);
        }
        throw res;
      }
      if (res is SSHNPCommand) {
        stdout.write('$res\n');
        await sshnp!.done;
        exit(0);
      }
      if (res is SSHNPNoOpSuccess) {
        stderr.write('$res\n');
        await sshnp!.done;
        exit(0);
      }
    } on ArgumentError catch (error, stackTrace) {
      usageCallback(error, stackTrace);
      exit(1);
    } on SSHNPError catch (error, stackTrace) {
      stderr.writeln(error.toString());
      if (verbose) {
        stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
      }
      exit(1);
    }
  }, (Object error, StackTrace stackTrace) async {
    if (error is ArgumentError) return;
    if (error is SSHNPError) return;
    stderr.writeln('Unknown error: ${error.toString()}');
    if (verbose) {
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    }
    exit(1);
  });
}

void usageCallback(Object e, StackTrace s) {
  printVersion();
  stderr.writeln(SSHNPPartialParams.parser.usage);
  stderr.writeln('\n$e');
}

void printDevices(
  Iterable<String> active,
  Iterable<String> off,
  Map<String, dynamic> info,
) {
  if (active.isEmpty && off.isEmpty) {
    stderr.writeln('[X] No devices found\n');
    stderr.writeln(
        'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command.');
    stderr.writeln(
        'Please update your devices to sshnpd version >= 3.4.0 and try again.');
    exit(0);
  }

  stderr.writeln('Active Devices:');
  printDeviceList(active, info);
  stderr.writeln('Inactive Devices:');
  printDeviceList(off, info);
}

void printDeviceList(Iterable<String> devices, Map<String, dynamic> info) {
  if (devices.isEmpty) {
    stderr.writeln('  No devices found');
    return;
  }
  for (var device in devices) {
    stderr.writeln('  $device - v${info[device]?['version']}');
  }
}
