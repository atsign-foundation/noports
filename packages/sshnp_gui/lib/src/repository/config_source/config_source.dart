import 'dart:io';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';

part 'config_sync_source.dart';
part 'config_file_source.dart';

/// Generic Type
abstract class ConfigSource {
  DateTime get lastModified;
  SSHNPParams get params;

  Future<void> create(SSHNPParams params);
  Future<SSHNPParams> read();
  Future<void> update(SSHNPParams params);
  Future<void> delete(SSHNPParams params);

  factory ConfigSource.synced(String profileName, {AtClient? atClient}) {
    return ConfigSyncSource.synced(profileName, atClient: atClient);
  }

  factory ConfigSource.exported(String profileName, directory) {
    return ConfigFileSource.exported(profileName, directory);
  }

  factory ConfigSource.imported(String profileName, directory) {
    return ConfigFileSource.imported(profileName, directory);
  }

  factory ConfigSource.sandboxed(String profileName) {
    return ConfigFileSource.sandboxed(profileName);
  }
}
