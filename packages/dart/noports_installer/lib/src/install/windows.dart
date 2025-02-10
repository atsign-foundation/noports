import 'dart:async';
import 'dart:io';

import 'package:args/args.dart' show ArgParser;
import 'package:noports_installer/src/install/install_status.dart';
import 'package:noports_installer/src/install/install_step.dart';
import 'package:noports_installer/src/types.dart';
import 'package:path/path.dart' as path;

import 'install_platform.dart';

class WindowsInstallPlatform extends InstallPlatform<WindowsPermissions> {
  @override
  // for now only x64 is supported on windows
  final PlatformArch arch = PlatformArch.x64;

  @override
  FutureOr<bool> get hasElevatedPermissions => throw UnimplementedError();

  @override
  String? get homeDir {
    var profile = Platform.environment['USERPROFILE'];
    if (profile == null) return profile;
    return path.canonicalize(profile);
  }

  @override
  FutureOr<String?> get atKeysDir => throw UnimplementedError();

  @override
  FutureOr<String?> get resolvedBinaryDir => throw UnimplementedError();

  @override
  final String defaultBinaryDir = r"C:\\Windows\Program Files\NoPorts";

  @override
  WindowsPermissions get permissions => WindowsPermissions();

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

class WindowsPermissions extends PlatformPermissions {
  final Set<String> permittedAccessGroups = {};

  @override
  FutureOr<bool?> setFileSystemPermissions(FileSystemEntity entity) {
    // TODO: implement setFileSystemPermissions
    throw UnimplementedError();
  }
}
