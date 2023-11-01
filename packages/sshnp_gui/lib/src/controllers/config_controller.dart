import 'dart:async';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';

enum ConfigFileWriteState { create, update }

/// A provider that exposes the [CurrentConfigController] to the app.
final currentConfigController =
    AutoDisposeNotifierProvider<CurrentConfigController, CurrentConfigState>(
  CurrentConfigController.new,
);

/// A provider that exposes the [ConfigListController] to the app.
final configListController =
    AutoDisposeAsyncNotifierProvider<ConfigListController, Iterable<String>>(
  ConfigListController.new,
);

/// A provider that exposes the [ConfigFamilyController] to the app.
final configFamilyController = AutoDisposeAsyncNotifierProviderFamily<
    ConfigFamilyController, SshnpParams, String>(
  ConfigFamilyController.new,
);

/// Holder model for the current [SshnpParams] being edited
class CurrentConfigState {
  final String profileName;
  final ConfigFileWriteState configFileWriteState;

  CurrentConfigState(
      {required this.profileName, required this.configFileWriteState});
}

/// Controller for the current [SshnpParams] being edited
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

/// Controller for the family of [SshnpParams] controllers
class ConfigFamilyController
    extends AutoDisposeFamilyAsyncNotifier<SshnpParams, String> {
  @override
  Future<SshnpParams> build(String arg) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    if (arg.isEmpty) {
      return SshnpParams.merge(
        SshnpParams.empty(),
        SshnpPartialParams(clientAtSign: atClient.getCurrentAtSign()!),
      );
    }
    return ConfigKeyRepository.getParams(arg, atClient: atClient);
  }

  Future<void> putConfig(SshnpParams params,
      {String? oldProfileName, BuildContext? context}) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    SshnpParams oldParams = state.value ?? SshnpParams.empty();
    if (oldProfileName != null) {
      ref
          .read(configFamilyController(oldProfileName).notifier)
          .deleteConfig(context: context);
    }
    if (params.clientAtSign != atClient.getCurrentAtSign()) {
      params = SshnpParams.merge(
        params,
        SshnpPartialParams(
          clientAtSign: atClient.getCurrentAtSign(),
        ),
      );
    }
    state = AsyncValue.data(params);
    try {
      await ConfigKeyRepository.putParams(params, atClient: atClient);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update profile: $arg');
      }
      state = AsyncValue.data(oldParams);
    }
    ref.read(configListController.notifier).add(params.profileName!);
  }

  Future<void> deleteConfig({BuildContext? context}) async {
    try {
      await ConfigKeyRepository.deleteParams(arg,
          atClient: AtClientManager.getInstance().atClient);
      ref.read(configListController.notifier).remove(arg);
      state =
          AsyncValue.error('SSHNPParams has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete profile: $arg');
      }
    }
  }
}
