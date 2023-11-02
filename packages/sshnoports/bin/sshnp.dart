// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';

// local packages
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshnp_params.dart' show ParserType, SshnpArg;
import 'package:noports_core/utils.dart';
import 'package:sshnoports/create_at_client_cli.dart';
import 'package:sshnoports/print_version.dart';
import 'package:sshnoports/sshnp.dart';

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';
  AtSignLogger.defaultLoggingHandler = AtSignLogger.stdErrLoggingHandler;

  late final SshnpParams params;
  Sshnp? sshnp;

  // Manually check if the verbose flag is set
  Set<String> verboseSet = SshnpArg.fromName('verbose').aliasList.toSet();
  final bool verbose = args.toSet().intersection(verboseSet).isNotEmpty;

  // Manually check if the help flag is set
  Set<String> helpSet = SshnpArg.fromName('help').aliasList.toSet();
  final bool help = args.toSet().intersection(helpSet).isNotEmpty;

  if (help) {
    printVersion();
    stderr.writeln(
        SshnpArg.createArgParser(parserType: ParserType.commandLine).usage);
    exit(0);
  }

  await runZonedGuarded(() async {
    try {
      params = SshnpParams.fromPartial(
        SshnpPartialParams.fromArgList(
          args,
          parserType: ParserType.commandLine,
        ),
      );
      String homeDirectory = getHomeDirectory()!;
      sshnp = await sshnpFromParamsWithFileBindings(
        params,
        atClientGenerator: (SshnpParams params) => createAtClientCli(
          homeDirectory: homeDirectory,
          atsign: params.clientAtSign,
          namespace: '${params.device}.sshnp',
          atKeysFilePath: params.atKeysFilePath ??
              getDefaultAtKeysFilePath(homeDirectory, params.clientAtSign),
          rootDomain: params.rootDomain,
        ),
      ).catchError((e) {
        if (e.stackTrace != null) {
          Error.throwWithStackTrace(e, e.stackTrace!);
        }
        throw e;
      });

      if (params.listDevices) {
        stderr.writeln('Searching for devices...');
        var deviceList = await sshnp!.listDevices();
        printDevices(deviceList);
        exit(0);
      }

      FutureOr<SshnpResult> runner = sshnp!.run();
      if (runner is Future<SshnpResult>) {
        await runner.catchError((e) {
          if (e.stackTrace != null) {
            Error.throwWithStackTrace(e, e.stackTrace!);
          }
          throw e;
        });
      }
      SshnpResult res = await runner;

      if (res is SshnpError) {
        if (res.stackTrace != null) {
          Error.throwWithStackTrace(res, res.stackTrace!);
        }
        throw res;
      }
      if (res is SshnpCommand || res is SshnpNoOpSuccess) {
        stdout.write('$res\n');
        exit(0);
      }
    } on ArgumentError catch (error, stackTrace) {
      usageCallback(error, stackTrace);
      exit(1);
    } on SshnpError catch (error, stackTrace) {
      stderr.writeln(error.toString());
      if (verbose) {
        stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
      }
      exit(1);
    }
  }, (Object error, StackTrace stackTrace) async {
    if (error is ArgumentError) return;
    if (error is SshnpError) return;
    stderr.writeln('Unknown error: ${error.toString()}');
    if (verbose) {
      stderr.writeln('\nStack Trace: ${stackTrace.toString()}');
    }
    exit(1);
  });
}

void usageCallback(Object e, StackTrace s) {
  printVersion();
  stderr.writeln(
      SshnpArg.createArgParser(parserType: ParserType.commandLine).usage);
  stderr.writeln('\n$e');
}

void printDevices(SshnpDeviceList deviceList) {
  if (deviceList.activeDevices.isEmpty && deviceList.inactiveDevices.isEmpty) {
    stderr.writeln('[X] No devices found\n');
    stderr.writeln(
        'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command.');
    stderr.writeln(
        'Please update your devices to sshnpd version >= 3.4.0 and try again.');
    exit(0);
  }

  stderr.writeln('Active Devices:');
  printDeviceList(deviceList.activeDevices, deviceList.info);
  stderr.writeln('Inactive Devices:');
  printDeviceList(deviceList.inactiveDevices, deviceList.info);
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
