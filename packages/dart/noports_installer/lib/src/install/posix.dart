import 'dart:async';
import 'dart:io';

import 'package:noports_installer/src/types.dart';
import 'package:posix/posix.dart' as posix;
import 'package:path/path.dart' as path;

import 'install_platform.dart';

mixin PosixPlatform<P extends PlatformPermissions> on InstallPlatform<P> {
  @override
  PlatformArch get arch {
    String arch = posix.uname().machine;
    return switch ((os, arch)) {
      (_, 'arm64') => PlatformArch.arm64,
      (_, 'aarch64') => PlatformArch.arm64,
      (_, 'x86_64') => PlatformArch.x64,
      (_, 'x64') => PlatformArch.x64,
      (_, 'amd64') => PlatformArch.x64,
      ('linux', 'arm') => PlatformArch.armv7,
      ('linux', 'armv7l') => PlatformArch.armv7,
      ('linux', 'riscv64') => PlatformArch.riscv,
      _ => throw UnsupportedError("Architecture '$arch' is not supported"),
    };
  }

  String get currentUser {
    int uid = posix.getuid();
    return posix.getUserNameByUID(uid);
  }

  @override
  bool get hasElevatedPermissions => posix.geteuid() == 0;

  @override
  String? get homeDir {
    // FIXME: handle running under sudo
    var profile = Platform.environment['HOME'];
    if (profile == null) return profile;
    return path.canonicalize(profile);
  }

  @override
  FutureOr<String?> get atKeysDir => throw UnimplementedError();

  @override
  String get resolvedBinaryDir =>
      hasElevatedPermissions ? defaultBinaryDir : "$homeDir/.local/bin";

  @override
  String get defaultBinaryDir => "/usr/local/bin";
}

mixin PosixPermissions on PlatformPermissions {
  String get appUser {
    // TODO check for SUDO_USER and other indicators
    return "";
  }

  @override
  FutureOr<bool?> setFileSystemPermissions(FileSystemEntity entity) {
    // TODO: implement setFileSystemPermissions
    throw UnimplementedError();
  }
}
