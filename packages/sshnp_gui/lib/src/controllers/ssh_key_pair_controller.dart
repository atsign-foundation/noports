import 'dart:async';
import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/application/at_ssh_key_pair_manager.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/repository/at_ssh_key_manager_pair_repository.dart';

enum AtSSHKeyPairFileWriteState { create, update }

/// A provider that exposes the [CurrentAtSSHKeyPairController] to the app.
final currentAtSSHKeyPairController =
    AutoDisposeNotifierProvider<CurrentAtSSHKeyPairController, CurrentAtSSHKeyPairState>(
  CurrentAtSSHKeyPairController.new,
);

/// A provider that exposes the [AtSshKeyPairListController] to the app.
final atSshKeyPairListController =
    AutoDisposeAsyncNotifierProvider<AtSshKeyPairManagerListController, Iterable<String>>(
  AtSshKeyPairManagerListController.new,
);

/// A provider that exposes the [AtSshKeyPairManagerFamilyController] to the app.
final atSSHKeyPairManagerFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<AtSshKeyPairManagerFamilyController, AtSshKeyPairManager, String>(
  AtSshKeyPairManagerFamilyController.new,
);

/// Holder model for the current [SSHNPParams] being edited
class CurrentAtSSHKeyPairState {
  final String nickname;
  final AtSSHKeyPairFileWriteState sshKeyPairFileWriteState;

  CurrentAtSSHKeyPairState({required this.nickname, required this.sshKeyPairFileWriteState});
}

/// Controller for the current [SSHNPParams] being edited
class CurrentAtSSHKeyPairController extends AutoDisposeNotifier<CurrentAtSSHKeyPairState> {
  @override
  CurrentAtSSHKeyPairState build() {
    return CurrentAtSSHKeyPairState(
      nickname: '',
      sshKeyPairFileWriteState: AtSSHKeyPairFileWriteState.create,
    );
  }

  void setState(CurrentAtSSHKeyPairState model) {
    state = model;
  }
}

/// Controller for the list of all profileNames for each config file
class AtSshKeyPairManagerListController extends AutoDisposeAsyncNotifier<Iterable<String>> {
  @override
  Future<Iterable<String>> build() async {
    return await AtSshKeyPairManagerRepository.listAtSshKeyPairIdentities();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String identity) async {
    state = AsyncValue.data({...state.value ?? [], identity});
    await AtSshKeyPairManagerRepository.writeAtSshKeyPairIdentities(state.value!.toList());
  }

  void remove(String identity) {
    // TODO: implement remove
    // state = AsyncData(state.value?.where((e) => e != profileName) ?? []);
  }
}

/// Controller for the family of [AtSSHKeyPairManager] controllers
class AtSshKeyPairManagerFamilyController extends AutoDisposeFamilyAsyncNotifier<AtSshKeyPairManager, String> {
  @override
  Future<AtSshKeyPairManager> build(String arg) async {
    if (arg.isEmpty) {
      AtSshKeyPairManager.empty();
    }
    final store = await BiometricStorage().getStorage('com.atsign.sshnoports.ssh-$arg');
    final data = await store.read();
    if (data.isNull || data!.isEmpty) {
      return AtSshKeyPairManager.empty();
    }

    return AtSshKeyPairManager.fromJson(jsonDecode(data));
  }

  Future<void> saveAtSshKeyPairManager(
      {required AtSshKeyPairManager atSshKeyPairManager, BuildContext? context}) async {
    try {
      AtSshKeyPairManagerRepository.writeAtSshKeyPair(atSshKeyPairManager);
      state = AsyncValue.data(atSshKeyPairManager);
      ref.read(atSshKeyPairListController.notifier).add(atSshKeyPairManager.nickname);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update AtSSHKeyPair: $arg');
      }
    }
  }

  Future<void> deleteAtSSHKeyPairManager({required String identifier, BuildContext? context}) async {
    try {
      AtSshKeyPairManagerRepository.deleteAtSshKeyPair(arg);
      ref.read(atSshKeyPairListController.notifier).remove(arg);
      state = AsyncValue.error('SSHNPParams has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete profile: $arg');
      }
    }
  }
}
