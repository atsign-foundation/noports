import 'dart:async';

import 'package:args/args.dart' show ArgParser;
import 'package:noports_installer/src/install/install_status.dart';
import 'package:noports_installer/src/install/install_step.dart';

import 'posix.dart';
import 'install_platform.dart';

class LinuxInstallPlatform extends InstallPlatform<LinuxPermissions>
    with PosixPlatform {
  const LinuxInstallPlatform();

  @override
  final LinuxPermissions permissions = const LinuxPermissions();

  @override
  ArgParser setPlatformArgs(ArgParser argParser) {
    throw UnimplementedError();
  }

  @override
  Future<InstallResult> platformInstall(List<List<InstallStep>> phases,
      StreamController<InstallStatus> controller) {
    // TODO: implement platformInstall
    throw UnimplementedError();
  }
}

class LinuxPermissions extends PlatformPermissions with PosixPermissions {
  const LinuxPermissions();
}
