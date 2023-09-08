import 'dart:async';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

enum ConfigFileWriteState { create, update }


/// A provider that exposes the [SSHNPParamsController] to the app.
final sshnpParamsController = AutoDisposeNotifierProvider<SSHNPParamsController, CurrentSSHNPParamsModel>(
  SSHNPParamsController.new,
);

/// A provider that exposes the [SSHNPParamsListController] to the app.
final sshnpParamsListController = AutoDisposeAsyncNotifierProvider<SSHNPParamsListController, Set<String>>(
  SSHNPParamsListController.new,
);

/// A provider that exposes the [SSHNPParamsFamilyController] to the app.
final sshnpParamsFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<SSHNPParamsFamilyController, SSHNPParams, String>(
  SSHNPParamsFamilyController.new,
);

/// Holder model for the current [SSHNPParams] being edited
class CurrentSSHNPParamsModel {
  final String profileName;
  final ConfigFileWriteState configFileWriteState;

  CurrentSSHNPParamsModel({required this.profileName, required this.configFileWriteState});
}

/// Controller for the current [SSHNPParams] being edited
class SSHNPParamsController extends AutoDisposeNotifier<CurrentSSHNPParamsModel> {
  @override
  CurrentSSHNPParamsModel build() {
    return CurrentSSHNPParamsModel(
      profileName: '',
      configFileWriteState: ConfigFileWriteState.create,
    );
  }

  void setState(CurrentSSHNPParamsModel model) {
    state = model;
  }
}

/// Controller for the list of all profileNames for each config file
class SSHNPParamsListController extends AutoDisposeAsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return (await SSHNPParams.listFiles()).toSet();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String profileName) {
    state = AsyncValue.data({...state.value ?? [], profileName});
  }

  void remove(String profileName) {
    state = AsyncData(state.value?.difference({profileName}) ?? {});
  }
}

/// Controller for the family of [SSHNPParams] controllers
class SSHNPParamsFamilyController extends AutoDisposeFamilyAsyncNotifier<SSHNPParams, String> {
  @override
  Future<SSHNPParams> build(String arg) async {
    return (await SSHNPParams.fileExists(arg))
        ? await SSHNPParams.fromFile(arg)
        : SSHNPParams.merge(
            SSHNPParams.empty(),
            SSHNPPartialParams(clientAtSign: AtClientManager.getInstance().atClient.getCurrentAtSign()!),
          );
  }

  Future<void> refresh(String arg) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> create(SSHNPParams params) async {
    await params.toFile();
    state = AsyncValue.data(params);
    ref.read(sshnpParamsListController.notifier).add(params.profileName!);
  }

  Future<void> edit(SSHNPParams params) async {
    await params.toFile(overwrite: true);
    state = AsyncValue.data(params);
  }

  Future<void> delete() async {
    await state.value?.deleteFile();
    state = const AsyncError('File deleted', StackTrace.empty);
    ref.read(sshnpParamsListController.notifier).remove(state.value!.profileName!);
  }
}
