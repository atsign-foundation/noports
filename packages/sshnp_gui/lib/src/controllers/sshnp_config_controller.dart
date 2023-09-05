import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

final sshnpConfigController = AutoDisposeAsyncNotifierProviderFamily<
    SSHNPConfigContoller,
    Map<String, SSHNPParams>,
    String>(SSHNPConfigContoller.new);

class SSHNPConfigContoller
    extends AutoDisposeFamilyAsyncNotifier<Map<String, SSHNPParams>, String> {
  @override
  Future<Map<String, SSHNPParams>> build(String arg) async {
    return Map.fromIterable(
      await SSHNPParams.getConfigFilesFromDirectory(),
      key: (e) => e
          .profileName!, // Profile name should never be null when using getConfigFilesFromDirectory
    );
  }

  void addConfig(SSHNPParams params) {
    update((p0) async {
      if (p0.containsKey(params.profileName!)) {
        throw Exception('Profile ${params.profileName} already exists');
      }
      await params.toFile();
      p0[params.profileName!] = params;
      return p0;
    });
  }

  void updateConfig(String profileName, SSHNPPartialParams newParams) {
    update((p0) async {
      if (!p0.containsKey(profileName)) {
        throw Exception('Profile $profileName does not exist');
      }
      var params = SSHNPParams.merge(p0[profileName]!, newParams);
      await params.toFile(overwrite: true);
      p0[profileName] = params;
      return p0;
    });
  }

  void deleteConfig(String profileName) {
    update((p0) async {
      if (!p0.containsKey(profileName)) {
        throw Exception('Profile $profileName does not exist');
      }
      await p0[profileName]!.deleteFile();
      p0.remove(profileName);
      return p0;
    });
  }
}
