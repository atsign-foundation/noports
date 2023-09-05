import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

/// Controller instance for the current [SSHNPParams] being edited
final currentParamsController = AutoDisposeNotifierProvider<
    CurrentSSHNPParamsController, CurrentSSHNPParamsModel>(
  () => CurrentSSHNPParamsController(),
);

/// Controller instance for the list of all profileNames for each config file
final paramsListController = AutoDisposeAsyncNotifierProvider<
    SSHNPParamsListController, Iterable<String>>(SSHNPParamsListController.new);

/// Controller instance for the family of [SSHNPParams] controllers
final paramsFamilyController = AutoDisposeAsyncNotifierProviderFamily<
    SSHNPParamsFamilyController,
    SSHNPParams,
    String>(SSHNPParamsFamilyController.new);

/// Holder model for the current [SSHNPParams] being edited
class CurrentSSHNPParamsModel {
  final String profileName;
  final ConfigFileWriteState configFileWriteState;

  CurrentSSHNPParamsModel(
      {required this.profileName, required this.configFileWriteState});
}

/// Controller for the current [SSHNPParams] being edited
class CurrentSSHNPParamsController
    extends AutoDisposeNotifier<CurrentSSHNPParamsModel> {
  @override
  CurrentSSHNPParamsModel build() {
    return CurrentSSHNPParamsModel(
      profileName: '',
      configFileWriteState: ConfigFileWriteState.create,
    );
  }

  void update(CurrentSSHNPParamsModel model) {
    state = model;
  }
}

/// Controller for the family of [SSHNPParams] controllers
class SSHNPParamsFamilyController
    extends AutoDisposeFamilyAsyncNotifier<SSHNPParams, String> {
  @override
  Future<SSHNPParams> build(String arg) async {
    return (await SSHNPParams.fileExists(arg))
        ? await SSHNPParams.fromFile(arg)
        : SSHNPParams.empty();
  }
}

/// Controller for the list of all profileNames for each config file
class SSHNPParamsListController
    extends AutoDisposeAsyncNotifier<Iterable<String>> {
  @override
  Future<Iterable<String>> build() {
    return SSHNPParams.listFiles();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
