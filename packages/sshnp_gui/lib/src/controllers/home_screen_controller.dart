import 'dart:developer';
import 'dart:io';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshrv/sshrv.dart';

/// A Controller class that controls the UI update when the [AtDataRepository] methods are called.
class HomeScreenController extends StateNotifier<AsyncValue<List<SSHNP>>> {
  final Ref ref;

  HomeScreenController({required this.ref}) : super(const AsyncValue.loading());

  late Iterable<SSHNPParams> sshnpParams;

  /// Get list of config files associated with the current astign.
  Future<void> getConfigFiles() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        sshnpParams = await SSHNPParams.getConfigFilesFromDirectory();

        final sshnpList = await Future.wait(sshnpParams
            .map((e) => SSHNP.fromParams(
                  e,
                  atClient: AtClientManager.getInstance().atClient,
                  sshrvGenerator: SSHRV.pureDart,
                ))
            .toList());
        return sshnpList;
      } on PathNotFoundException {
        log('Path Not Found');
        return [];
      }
    });
  }

  /// Deletes the [AtKey] associated with the [AtData].
  Future<void> delete(int index) async {
    state = const AsyncValue.loading();
    final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var configDir = await Directory(directory).list().toList();
    configDir[index].delete();
    await getConfigFiles();
  }

  /// Deletes all [AtData] associated with the current atsign.
  Future<void> deleteAllData() async {
    state = const AsyncValue.loading();
    final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var configDir = await Directory(directory).list().toList();
    configDir.map((e) => e.delete());
    await getConfigFiles();
  }

  /// create or update config files.
  Future<void> createConfigFile(SSHNPParams sshnpParams, {bool update = false}) async {
    state = const AsyncValue.loading();
    final homeDir = getHomeDirectory()!;
    log(homeDir);
    final configDir = getDefaultSshnpConfigDirectory(homeDir);
    log(configDir);
    await Directory(configDir).create(recursive: true);
    //.env
    sshnpParams.toFile('$configDir/${sshnpParams.clientAtSign}-${sshnpParams.sshnpdAtSign}-${sshnpParams.device}.env',
        overwrite: update);
    await getConfigFiles();
  }
}

/// A provider that exposes the [HomeScreenController] to the app.
final homeScreenControllerProvider =
    StateNotifierProvider<HomeScreenController, AsyncValue<List<SSHNP>>>((ref) => HomeScreenController(ref: ref));
