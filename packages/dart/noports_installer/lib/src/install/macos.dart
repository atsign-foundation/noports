import 'dart:async';

import 'package:args/args.dart' show ArgParser;
import 'package:noports_installer/src/install/install_status.dart';
import 'package:noports_installer/src/install/install_step.dart';

import 'install_platform.dart';
import 'posix.dart';

class MacosInstallPlatform extends InstallPlatform<MacosPermissions>
    with PosixPlatform {
  const MacosInstallPlatform();

  @override
  final MacosPermissions permissions = const MacosPermissions();

  @override
  ArgParser setPlatformArgs(ArgParser argParser) {
    // TODO: implement setPlatformArgs
    throw UnimplementedError();
  }

  @override
  Future<InstallResult> platformInstall(List<List<InstallStep>> phases,
      StreamController<InstallStatus> controller) {
    // TODO: implement platformInstall
    throw UnimplementedError();
  }
}

class MacosPermissions extends PlatformPermissions with PosixPermissions {
  const MacosPermissions();
}
