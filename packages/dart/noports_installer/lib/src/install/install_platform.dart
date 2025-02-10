import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_installer/src/install/install_status.dart';
import 'package:noports_installer/src/install/install_step.dart';
import 'package:noports_installer/src/types.dart';

import 'linux.dart';
import 'macos.dart';
import 'windows.dart';

abstract class InstallPlatform<Perms extends PlatformPermissions> {
  /// Current OS (using dart:io platform format, not uname format)
  String get os => Platform.operatingSystem;

  /// normalized platform architecture (uname -m)
  FutureOr<PlatformArch> get arch;

  /// whether the installer process is running as root/admin
  FutureOr<bool> get hasElevatedPermissions;

  /// home dir of the [appUser]
  FutureOr<String?> get homeDir;

  /// atkeys dir of the [appUser]
  FutureOr<String?> get atKeysDir;

  /// resolved path to where installed binaries will be located
  FutureOr<String?> get resolvedBinaryDir;

  /// Default binary dir for the platform
  FutureOr<String> get defaultBinaryDir;

  /// Permissions utility for the platform
  FutureOr<Perms> get permissions;

  const InstallPlatform();

  factory InstallPlatform.get() {
    return instance as InstallPlatform<Perms>;
  }

  static final InstallPlatform instance = _get();
  static InstallPlatform _get() {
    final String os = Platform.operatingSystem;
    switch (os) {
      case 'macos':
        return MacosInstallPlatform();
      case 'linux':
        return LinuxInstallPlatform();
      case 'windows':
        return WindowsInstallPlatform();
      default:
        throw UnsupportedError("$os is unsupported");
    }
  }

  /// Set platform specific arguments for the arg parser
  ArgParser setPlatformArgs(ArgParser argParser);

  ArgParser getArgParser() {
    ArgParser parser = ArgParser();
    // TODO  handle global args
    parser = setPlatformArgs(parser);
    return parser;
  }

  Future<InstallResult> platformInstall(List<List<InstallStep>> phases,
      StreamController<InstallStatus> controller);

  static (Future<InstallResult>, Stream<InstallStatus>) install(
      Set<InstallStep> steps) {
    StreamController<InstallStatus> controller = StreamController();
    Completer<InstallResult> completer = Completer();

    List<List<InstallStep>> phases = [];

    var binarySteps = steps.where((e) => e.type == InstallType.binary).toList();
    if (binarySteps.isNotEmpty) {
      phases.add(binarySteps);
    }

    var atKeysSteps = steps.where((e) => e.type == InstallType.atKeys).toList();
    if (atKeysSteps.isNotEmpty) {
      phases.add(atKeysSteps);
    }

    var serviceSteps =
        steps.where((e) => e.type == InstallType.service).toList();
    if (serviceSteps.isNotEmpty) {
      phases.add(serviceSteps);
    }

    instance.platformInstall(phases, controller).then((value) {
      completer.complete(value);
    }).onError((e, st) {
      completer.complete(InstallFailure(e, st));
    });

    return (completer.future, controller.stream);
  }
}

abstract class PlatformPermissions {
  const PlatformPermissions();

  FutureOr<bool?> setFileSystemPermissions(FileSystemEntity entity);
}
