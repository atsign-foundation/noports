import 'dart:async';
import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/util/uuid.dart';

import '../../profile_list/cubit/sync_cubit.dart';

class ProfileProgressListener extends SyncProgressListener {
  ProfileProgressListener() {
    Stream<AtNotification> subscription = AtClientManager.getInstance()
        .atClient
        .notificationService
        .subscribe(
            regex:
                '\\.${Uuid.profilesSubNamespace}\\.${Constants.namespace!}@');
    subscription.listen((AtNotification n) async {
      try {
        final profileListBlock =
            App.navState.currentContext!.read<ProfileListBloc>();

        App.log('[INFO] Notification $n'.loggable);
        if (n.key.contains(
            '.${Uuid.profilesSubNamespace}.${Constants.namespace!}')) {
          switch (n.operation) {
            case 'update':
              AtClientManager.getInstance().atClient.syncService.sync();
              break;

            case 'delete':
              await AtClientManager.getInstance()
                  .atClient
                  .getLocalSecondary()!
                  .keyStore!
                  .remove('cached:${n.key}', skipCommit: true);
              profileListBlock.add(const ProfileListLoadEvent());
              log('ProfileProgressListener: ProfileListLoadEvent triggered to reload profiles');
              break;

            default:
              break;
          }
        }
      } catch (ignore) {
        App.log('[ERROR] Caught $ignore while listening to notifications.'
                ' Ignoring and continuing.'
            .loggable);
      }
    });
  }

  @override
  void onSyncProgressEvent(SyncProgress syncProgress) async {
    unawaited(App.navState.currentContext!.read<SyncCubit>().checkSync());
    final profileListBlock =
        App.navState.currentContext!.read<ProfileListBloc>();

    bool profileSynced() {
      for (final KeyInfo ki in syncProgress.keyInfoList ?? []) {
        App.log('[DEBUG] sync keyInfo: $ki'.loggable);
        if (ki.syncDirection == SyncDirection.remoteToLocal) {
          if (ki.key.contains(
              '.${Uuid.profilesSubNamespace}.${Constants.namespace!}')) {
            return true;
          }
        }
      }
      return false;
    }

    if (syncProgress.syncStatus == SyncStatus.success &&
        profileListBlock.state is ProfileListLoaded &&
        (profileSynced() ||
            (profileListBlock.state as ProfileListLoaded).profiles.isEmpty)) {
      profileListBlock.add(const ProfileListLoadEvent());
      log('ProfileProgressListener: ProfileListLoadEvent triggered to reload profiles');
      unawaited(App.navState.currentContext!.read<SyncCubit>().checkSync());
    }
  }
}
