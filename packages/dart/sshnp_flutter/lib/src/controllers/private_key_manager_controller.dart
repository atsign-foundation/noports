import 'dart:async';
import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_flutter/src/repository/private_key_manager_repository.dart';
import 'package:sshnp_flutter/src/repository/profile_private_key_manager_repository.dart';

import '../application/private_key_manager.dart';
import '../repository/navigation_repository.dart';

enum PrivateKeyManagerWriteState { create, update }

/// A provider that exposes the [CurrentPrivateKeyManagerController] to the app.
final currentPrivateKeyController =
    AutoDisposeNotifierProvider<CurrentPrivateKeyManagerController, CurrentPrivateKeyManagerState>(
  CurrentPrivateKeyManagerController.new,
);

/// A provider that exposes the [AtSshKeyPairListController] to the app.
final atPrivateKeyManagerListController =
    AutoDisposeAsyncNotifierProvider<PrivateKeyManagerListController, Iterable<String>>(
  PrivateKeyManagerListController.new,
);

/// A provider that exposes the [AtSshKeyPairManagerFamilyController] to the app.
final privateKeyManagerFamilyController =
    AutoDisposeAsyncNotifierProviderFamily<AtSshKeyPairManagerFamilyController, PrivateKeyManager, String>(
  AtSshKeyPairManagerFamilyController.new,
);

/// Holder model for the current [PrivateKeyManager] being edited
class CurrentPrivateKeyManagerState {
  final String nickname;
  final PrivateKeyManagerWriteState sshKeyPairFileWriteState;

  CurrentPrivateKeyManagerState({required this.nickname, required this.sshKeyPairFileWriteState});
}

/// Controller for the current [PrivateKeyManager] being edited
class CurrentPrivateKeyManagerController extends AutoDisposeNotifier<CurrentPrivateKeyManagerState> {
  @override
  CurrentPrivateKeyManagerState build() {
    return CurrentPrivateKeyManagerState(
      nickname: '',
      sshKeyPairFileWriteState: PrivateKeyManagerWriteState.create,
    );
  }

  void setState(CurrentPrivateKeyManagerState model) {
    state = model;
  }
}

/// Controller for the list of all [PrivatekeyManager] nicknames
class PrivateKeyManagerListController extends AutoDisposeAsyncNotifier<Iterable<String>> {
  final context = NavigationRepository.navKey.currentContext!;
  @override
  Future<Iterable<String>> build() async {
    return await PrivateKeyManagerRepository.listPrivateKeyManagerNickname();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String identity) async {
    state = AsyncValue.data({...state.value ?? [], identity});
    await PrivateKeyManagerRepository.writePrivateKeyManagerNicknames(state.value!.toList());
  }

  Future<void> remove(String identity) async {
    final newState = state.value?.where((e) => e != identity) ?? [];
    await PrivateKeyManagerRepository.writePrivateKeyManagerNicknames(newState.toList());
    state = AsyncData(newState);
  }
}

/// Controller for the family of [AtSSHKeyPairManager] controllers
class AtSshKeyPairManagerFamilyController extends AutoDisposeFamilyAsyncNotifier<PrivateKeyManager, String> {
  @override
  Future<PrivateKeyManager> build(String arg) async {
    if (arg.isEmpty) {
      PrivateKeyManager.empty();
    }

    final data = await PrivateKeyManagerRepository.readPrivateKeyManager(arg);
    return data;
  }

  Future<void> savePrivateKeyManager({required PrivateKeyManager privateKeyManager, BuildContext? context}) async {
    try {
      PrivateKeyManagerRepository.writePrivateKeyManager(privateKeyManager);
      state = AsyncValue.data(privateKeyManager);
      ref.read(atPrivateKeyManagerListController.notifier).add(privateKeyManager.nickname);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update PrivateKeyManager: $arg');
      }
    }
  }

  Future<void> deletePrivateKeyManager({required String identifier, BuildContext? context}) async {
    try {
      ref.read(atPrivateKeyManagerListController.notifier).remove(arg);
      // Read in profiles
      AtClient atClient = AtClientManager.getInstance().atClient;
      final profiles = await ConfigKeyRepository.listProfiles(atClient);

      for (final profile in profiles) {
        //delete profile private key manager that matches the deleted private key manager
        final profilePrivateKeyManager = await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(profile);
        log('arg: $arg, profile $profile, profile private manager key nickname: ${profilePrivateKeyManager.privateKeyNickname}, profilePrivateKeyManager profile name: ${profilePrivateKeyManager.profileNickname}');

        if (profilePrivateKeyManager.privateKeyNickname == arg) {
          log('profile from if clause: $profile');
          await ProfilePrivateKeyManagerRepository.deleteProfilePrivateKeyManager(profile);
        }
      }

      state = AsyncValue.error('SSHNPParams has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete profile: $arg');
      }
    }
  }
}
