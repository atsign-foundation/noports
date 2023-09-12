import 'dart:async';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/config_manager.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

enum ConfigFileWriteState { create, update }

/// A provider that exposes the [CurrentConfigController] to the app.
final currentConfigController = AutoDisposeNotifierProvider<CurrentConfigController, CurrentConfigState>(
  CurrentConfigController.new,
);

/// A provider that exposes the [ConfigListController] to the app.
final configListController = AutoDisposeAsyncNotifierProvider<ConfigListController, Iterable<String>>(
  ConfigListController.new,
);

final configManagerProvider = Provider<ConfigManager>((ref) {
  return ConfigManager(AtClientManager.getInstance().atClient);
});

/// A provider that exposes the [ConfigFamilyController] to the app.
final configFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<ConfigFamilyController, ConfigFamilyManager, String>(
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
    await ref.read(configManagerProvider).initialized;
    return (ref.read(configManagerProvider).managers.keys).toSet();
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
class ConfigFamilyController extends AutoDisposeFamilyAsyncNotifier<ConfigFamilyManager, String> {
  @override
  Future<ConfigFamilyManager> build(String arg) {
    return ref.read(configManagerProvider)[arg];
  }

  Future<void> createConfig(SSHNPParams params) async {
    await state.value?.create(params);
    ref.read(configListController.notifier).add(params.profileName!);
  }

  Future<void> updateConfig(SSHNPParams params) async {
    await state.value?.update(params);
  }

  Future<void> deleteConfig() async {
    await state.value?.delete();
    ref.read(configListController.notifier).remove(state.value!.profileName);
  }
}
