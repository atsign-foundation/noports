import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/config_repository/config_key_repository.dart';

enum ConfigFileWriteState { create, update }

/// A provider that exposes the [CurrentConfigController] to the app.
final currentConfigController = AutoDisposeNotifierProvider<CurrentConfigController, CurrentConfigState>(
  CurrentConfigController.new,
);

/// A provider that exposes the [ConfigListController] to the app.
final configListController = AutoDisposeAsyncNotifierProvider<ConfigListController, Iterable<String>>(
  ConfigListController.new,
);

/// A provider that exposes the [ConfigFamilyController] to the app.
final configFamilyController = AutoDisposeAsyncNotifierProviderFamily<ConfigFamilyController, SSHNPParams, String>(
  ConfigFamilyController.new,
);

/// Holder model for the current [SSHNPParams] being edited
class CurrentConfigState {
  final String profileName;
  final ConfigFileWriteState configFileWriteState;

  CurrentConfigState({required this.profileName, required this.configFileWriteState});
}

/// Controller for the current [SSHNPParams] being edited
class CurrentConfigController extends AutoDisposeNotifier<CurrentConfigState> {
  @override
  CurrentConfigState build() {
    return CurrentConfigState(
      profileName: '',
      configFileWriteState: ConfigFileWriteState.create,
    );
  }

  void setState(CurrentConfigState model) {
    state = model;
  }
}

/// Controller for the list of all profileNames for each config file
class ConfigListController extends AutoDisposeAsyncNotifier<Iterable<String>> {
  @override
  Future<Iterable<String>> build() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    return Set.from(await ConfigKeyRepository.listProfiles(atClient));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String profileName) {
    state = AsyncValue.data({...state.value ?? [], profileName});
  }

  void remove(String profileName) {
    state = AsyncData(state.value?.where((e) => e != profileName) ?? []);
  }
}

/// Controller for the family of [SSHNPParams] controllers
class ConfigFamilyController extends AutoDisposeFamilyAsyncNotifier<SSHNPParams, String> {
  @override
  Future<SSHNPParams> build(String arg) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    if (arg.isEmpty) {
      return SSHNPParams.merge(
        SSHNPParams.empty(),
        SSHNPPartialParams(clientAtSign: atClient.getCurrentAtSign()!),
      );
    }
    return ConfigKeyRepository.getParams(arg, atClient: atClient);
  }

  Future<void> putConfig(SSHNPParams params) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    if (params.clientAtSign != atClient.getCurrentAtSign()) {
      params = SSHNPParams.merge(
        params,
        SSHNPPartialParams(
          clientAtSign: atClient.getCurrentAtSign(),
        ),
      );
    }
    await ConfigKeyRepository.putParams(params, atClient: atClient);
    ref.read(configListController.notifier).add(params.profileName!);
  }

  Future<void> deleteConfig() async {
    await ConfigKeyRepository.deleteParams(arg, atClient: AtClientManager.getInstance().atClient);
    ref.read(configListController.notifier).remove(arg);
  }
}
