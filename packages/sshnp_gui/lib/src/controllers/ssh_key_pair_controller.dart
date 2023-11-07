import 'dart:async';
import 'dart:convert';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/repository/at_ssh_key_pair_repository.dart';

enum AtSSHKeyPairFileWriteState { create, update }

/// A provider that exposes the [CurrentAtSSHKeyPairController] to the app.
final currentAtSSHKeyPairController =
    AutoDisposeNotifierProvider<CurrentAtSSHKeyPairController, CurrentAtSSHKeyPairState>(
  CurrentAtSSHKeyPairController.new,
);

/// A provider that exposes the [ConfigListController] to the app.
final AtSSHKeyPairListController = AutoDisposeAsyncNotifierProvider<ConfigListController, Iterable<String>>(
  ConfigListController.new,
);

/// A provider that exposes the [AtSSHKeyPairFamilyController] to the app.
final atSSHKeyPairFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<AtSSHKeyPairFamilyController, AtSSHKeyPair, String>(
  AtSSHKeyPairFamilyController.new,
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
class ConfigListController extends AutoDisposeAsyncNotifier<Iterable<String>> {
  @override
  Future<Iterable<String>> build() async {
    return await AtSSHKeyPairRepository.listAtSSHKeyPairIdentities();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String identity) async {
    state = AsyncValue.data({...state.value ?? [], identity});
    await AtSSHKeyPairRepository.writeAtSSHKeyPairIdentities(state.value!.toList());
  }

  void remove(String identity) {
    // TODO: implement remove
    // state = AsyncData(state.value?.where((e) => e != profileName) ?? []);
  }
}

/// Controller for the family of [AtSSHKeyPair] controllers
class AtSSHKeyPairFamilyController extends AutoDisposeFamilyAsyncNotifier<AtSSHKeyPair, String> {
  @override
  Future<AtSSHKeyPair> build(String arg) async {
    if (arg.isEmpty) {
      AtSSHKeyPair.fromPem('', identifier: '');
    }
    final store = await BiometricStorage().getStorage('com.atsign.sshnoports.ssh-$arg');
    final data = await store.read();

    // TODO: implement code to get atsshkeypair.
    return AtSSHKeyPair.fromJson(jsonDecode(data!));
  }

  Future<void> saveAtSSHKeyPair({required AtSSHKeyPair atSSHKeyPair, BuildContext? context}) async {
    try {
      AtSSHKeyPairRepository.writeAtSSHKeyPair(atSSHKeyPair);
      state = AsyncValue.data(atSSHKeyPair);
      ref.read(AtSSHKeyPairListController.notifier).add(atSSHKeyPair.identifier);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update AtSSHKeyPair: $arg');
      }
    }
  }

  Future<void> deleteAtSSHKeyPair({required String identifier, BuildContext? context}) async {
    try {
      AtSSHKeyPairRepository.deleteAtSSHKeyPair(arg);
      ref.read(AtSSHKeyPairListController.notifier).remove(arg);
      state = AsyncValue.error('SSHNPParams has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete profile: $arg');
      }
    }
  }
}
