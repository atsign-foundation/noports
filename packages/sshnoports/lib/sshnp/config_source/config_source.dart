import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:sshnoports/sshnp/config_file_utils.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

part 'config_sync_source.dart';
part 'config_file_source.dart';

/// Generic Type
abstract class ConfigSource {
  SSHNPParams get params;

  FutureOr<DateTime> getLastModified({bool refresh = true});
  Future<void> create(SSHNPParams params);
  Future<SSHNPParams> read();
  Future<void> update(SSHNPParams params);
  Future<void> delete();

  factory ConfigSource.file(String profileName, {String? directory, String? fileName}) =>
      ConfigFileSource(profileName, directory: directory, fileName: fileName);

  factory ConfigSource.sync(String profileName, AtClient atClient) => ConfigSyncSource(profileName, atClient);
}
