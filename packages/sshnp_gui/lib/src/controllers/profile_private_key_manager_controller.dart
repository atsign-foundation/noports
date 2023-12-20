import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';

import '../application/private_key_manager.dart';
import '../application/profile_private_key_manager.dart';
import '../repository/profile_private_key_manager_repository.dart';

enum ProfilePrivateKeyManagerWriteState { create, update }

/// A provider that exposes the [CurrentProfilePrivateKeyManagerController] to the app.
final currentProfilePrivateKeyManagerController =
    AutoDisposeNotifierProvider<CurrentPrivateKeyManagerController, CurrentProfilePrivateKeyManagerState>(
  CurrentPrivateKeyManagerController.new,
);

/// A provider that exposes the [ProfilePrivateKeyManagerListController] to the app.
final profilePrivateKeyManagerListController =
    AutoDisposeAsyncNotifierProvider<ProfilePrivateKeyManagerListController, Iterable<String>>(
  ProfilePrivateKeyManagerListController.new,
);

/// A provider that exposes the [ProfilePrivateKeyManagerFamilyController] to the app.
final profilePrivateKeyManagerFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<ProfilePrivateKeyManagerFamilyController, ProfilePrivateKeyManager, String>(
  ProfilePrivateKeyManagerFamilyController.new,
);

/// Holder model for the current [PrivateKeyManager] being edited
class CurrentProfilePrivateKeyManagerState {
  final String nickname;
  final ProfilePrivateKeyManagerWriteState profilePrivateKeyManagerWriteState;

  CurrentProfilePrivateKeyManagerState({required this.nickname, required this.profilePrivateKeyManagerWriteState});
}

/// Controller for the current [PrivateKeyManager] being edited
class CurrentPrivateKeyManagerController extends AutoDisposeNotifier<CurrentProfilePrivateKeyManagerState> {
  @override
  CurrentProfilePrivateKeyManagerState build() {
    return CurrentProfilePrivateKeyManagerState(
      nickname: '',
      profilePrivateKeyManagerWriteState: ProfilePrivateKeyManagerWriteState.create,
    );
  }

  void setState(CurrentProfilePrivateKeyManagerState model) {
    state = model;
  }
}

/// Controller for the list of all [PrivatekeyManager] nicknames
class ProfilePrivateKeyManagerListController extends AutoDisposeAsyncNotifier<Iterable<String>> {
  @override
  Future<Iterable<String>> build() async {
    return await ProfilePrivateKeyManagerRepository.listProfilePrivateKeyManagerNickname();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String identity) async {
    await ProfilePrivateKeyManagerRepository.writeProfilePrivateKeyManagerNicknames(state.value!.toList());
    state = AsyncValue.data({...state.value ?? [], identity});
  }

  Future<void> remove(String identity) async {
    final newState = state.value?.where((e) => e != identity) ?? [];
    await ProfilePrivateKeyManagerRepository.writeProfilePrivateKeyManagerNicknames(newState.toList());
    state = AsyncData(newState);
  }
}

/// Controller for the family of [ProfilePrivateKeyManager] controllers
class ProfilePrivateKeyManagerFamilyController
    extends AutoDisposeFamilyAsyncNotifier<ProfilePrivateKeyManager, String> {
  @override
  Future<ProfilePrivateKeyManager> build(String arg) async {
    if (arg.isEmpty) {
      PrivateKeyManager.empty();
    }
    final data = await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(arg);

    if (data == null) {
      return ProfilePrivateKeyManager.empty();
    }

    return data;
  }

  Future<void> saveProfilePrivateKeyManager(
      {required ProfilePrivateKeyManager profilePrivateKeyManager, BuildContext? context}) async {
    try {
      ProfilePrivateKeyManagerRepository.writeProfilePrivateKeyManager(profilePrivateKeyManager);
      state = AsyncValue.data(profilePrivateKeyManager);
      ref.read(profilePrivateKeyManagerListController.notifier).add(profilePrivateKeyManager.identifier);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update ProfilePrivateKeyManager: $arg');
      }
    }
  }

  Future<void> deleteProfilePrivateKeyManager({required String identifier, BuildContext? context}) async {
    try {
      await ProfilePrivateKeyManagerRepository.deleteProfilePrivateKeyManager(arg);
      ref.read(profilePrivateKeyManagerListController.notifier).remove(arg);
      state = AsyncValue.error('ProfilePrivate Key Manager has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete Profile PrivateKey Manager: $arg');
      }
    }
  }
}
