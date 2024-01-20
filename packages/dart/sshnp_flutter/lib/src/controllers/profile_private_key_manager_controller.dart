import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/custom_snack_bar.dart';

import '../application/private_key_manager.dart';
import '../application/profile_private_key_manager.dart';
import '../repository/profile_private_key_manager_repository.dart';

enum ProfilePrivateKeyManagerWriteState { create, update }

/// A provider that exposes the [CurrentProfilePrivateKeyManagerController] to the app.
final currentProfilePrivateKeyManagerController =
    AutoDisposeNotifierProvider<CurrentPrivateKeyManagerController, CurrentProfilePrivateKeyManagerState>(
  CurrentPrivateKeyManagerController.new,
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

/// Controller for the family of [ProfilePrivateKeyManager] controllers
class ProfilePrivateKeyManagerFamilyController
    extends AutoDisposeFamilyAsyncNotifier<ProfilePrivateKeyManager, String> {
  @override
  Future<ProfilePrivateKeyManager> build(String arg) async {
    if (arg.isEmpty) {
      PrivateKeyManager.empty();
    }
    final data = await ProfilePrivateKeyManagerRepository.readProfilePrivateKeyManager(arg);

    return data;
  }

  Future<void> saveProfilePrivateKeyManager(
      {required ProfilePrivateKeyManager profilePrivateKeyManager, BuildContext? context}) async {
    try {
      ProfilePrivateKeyManagerRepository.writeProfilePrivateKeyManager(profilePrivateKeyManager);
      state = AsyncValue.data(profilePrivateKeyManager);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to update ProfilePrivateKeyManager: $arg');
      }
    }
  }

  Future<void> deleteProfilePrivateKeyManager({required String identifier, BuildContext? context}) async {
    try {
      await ProfilePrivateKeyManagerRepository.deleteProfilePrivateKeyManager(arg);
      state = AsyncValue.error('ProfilePrivate Key Manager has been disposed', StackTrace.current);
    } catch (e) {
      if (context?.mounted ?? false) {
        CustomSnackBar.error(content: 'Failed to delete Profile PrivateKey Manager: $arg');
      }
    }
  }
}
