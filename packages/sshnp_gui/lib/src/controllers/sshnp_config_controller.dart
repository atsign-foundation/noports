import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

/// Controller instance for the current [SSHNPParams] being edited
final currentParamsController = AutoDisposeNotifierProvider<
    CurrentSSHNPParamsController,
    CurrentSSHNPParamsModel>(CurrentSSHNPParamsController.new);

/// Controller instance for the list of all profileNames for each config file
final paramsListController =
    AutoDisposeAsyncNotifierProvider<SSHNPParamsListController, Set<String>>(
        SSHNPParamsListController.new);

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

  void setState(CurrentSSHNPParamsModel model) {
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

  Future<void> refresh(String arg) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> create(SSHNPParams params) async {
    print('create');
    await params.toFile();
    state = AsyncValue.data(params);
    ref.read(paramsListController.notifier).add(params.profileName!);
  }

  Future<void> edit(SSHNPParams params) async {
    print('edit');
    await params.toFile(overwrite: true);
    state = AsyncValue.data(params);
  }

  Future<void> delete() async {
    await state.value?.deleteFile();
    state = const AsyncError('File deleted', StackTrace.empty);
    ref.read(paramsListController.notifier).remove(state.value!.profileName!);
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
