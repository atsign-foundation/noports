import 'dart:developer';
import 'dart:io';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';

/// A Controller class that controls the UI update when the [AtDataRepository] methods are called.
class HomeScreenController extends StateNotifier<AsyncValue<List<SSHNPParams>>> {
  final Ref ref;

  HomeScreenController({required this.ref}) : super(const AsyncValue.loading());

  /// Get list of config files associated with the current astign.
  Future<void> getConfigFiles() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        var sshnpParams = await SSHNPParams.getConfigFilesFromDirectory();
        for (var element in sshnpParams.toList()) {
          log(element.sshnpdAtSign.toString());
        }
        return sshnpParams.toList();
      } on PathNotFoundException {
        log('Path Not Found');
        return [];
      }
    });
  }

  Future<String> getPublicKeyFromDirectory() async {
    var homeDirectory = getHomeDirectory(throwIfNull: true)!;

    var files = Directory('$homeDirectory/.ssh').list();
    final publickey = await files.firstWhere((element) => element.path.contains('sshnp.pub'));

    return publickey.path.split('.ssh/').last;
  }

  /// Deletes the [AtKey] associated with the [AtData].
  Future<void> delete(int index) async {
    state = const AsyncValue.loading();
    final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var configDir = await Directory(directory).list().toList();
    // remove non env file so the index of the config file in the UI matches the index of the configDir env files.
    //TODO @CurtlyCritchlow this is no longer needed, you can now use [SSHNPParams.deleteFile()]
    configDir.removeWhere((element) => path.extension(element.path) != '.env');
    configDir[index].delete();
    await getConfigFiles();
  }

  // /// Deletes all [AtData] associated with the current atsign.
  // Future<void> deleteAllData() async {
  //   state = const AsyncValue.loading();
  //   final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
  //   var configDir = await Directory(directory).list().toList();
  //   configDir.map((e) => e.delete());
  //   await getConfigFiles();
  // }

  /// create or update config files.
  Future<void> createConfigFile(
    SSHNPParams sshnpParams,
  ) async {
    state = const AsyncValue.loading();
    final homeDir = getHomeDirectory()!;

    log(homeDir);
    final configDir = getDefaultSshnpConfigDirectory(homeDir);
    log(configDir);
    await Directory(configDir).create(recursive: true);
    //.env
    sshnpParams.toFile(overwrite: false);
    await getConfigFiles();
  }

  /// create or update config files.
  Future<void> updateConfigFile({required SSHNPParams sshnpParams}) async {
    state = const AsyncValue.loading();

    final directory = getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var configDir = await Directory(directory).list().toList();
    configDir.removeWhere((element) => path.extension(element.path) != '.env');
    final index = ref.read(sshnpParamsUpdateIndexProvider);
    log('path is:${configDir[index].path}');
    // await Directory(configDir).create(recursive: true);
    //.env
    sshnpParams.toFile(overwrite: true);
    await getConfigFiles();
  }
}

/// A provider that exposes the [HomeScreenController] to the app.
final homeScreenControllerProvider =
    StateNotifierProvider<HomeScreenController, AsyncValue<List<SSHNPParams>>>((ref) => HomeScreenController(ref: ref));
