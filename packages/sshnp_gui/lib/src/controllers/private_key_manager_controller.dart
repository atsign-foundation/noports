import 'dart:async';
import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_gui/src/repository/private_key_manager_repository.dart';

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
    try {
      return await PrivateKeyManagerRepository.listPrivateKeyManagerNickname();
    } on AuthException catch (e) {
      if (e.code == AuthExceptionCode.userCanceled) {
        context.pushReplacementNamed(AppRoute.home.name);
        CustomSnackBar.error(content: 'Operation canceled by user');
      } else if (e.code == AuthExceptionCode.timeout) {
        context.pushReplacementNamed(AppRoute.home.name);
        CustomSnackBar.error(content: 'Operation timed out. Please try again');
      } else {
        context.pushReplacementNamed(AppRoute.home.name);
        CustomSnackBar.error(content: 'An error occurred while retrieving the private key list. Please try again.');
      }
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void add(String identity) async {
    await PrivateKeyManagerRepository.writePrivateKeyManagerNicknames(state.value!.toList());
    state = AsyncValue.data({...state.value ?? [], identity});
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
    final store = await BiometricStorage().getStorage('com.atsign.sshnoports.ssh-$arg');
    final data = await store.read();
    if (data.isNull || data!.isEmpty) {
      return PrivateKeyManager.empty();
    }

    return PrivateKeyManager.fromJson(jsonDecode(data));
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
      await PrivateKeyManagerRepository.deletePrivateKeyManager(arg);
      ref.read(atPrivateKeyManagerListController.notifier).remove(arg);
      state = AsyncValue.error('SSHNPParams has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete profile: $arg');
      }
    }
  }
}
