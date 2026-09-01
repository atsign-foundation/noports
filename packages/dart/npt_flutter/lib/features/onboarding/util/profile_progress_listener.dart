import 'dart:async';
import 'dart:developer';

import 'package:at_client/at_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';

import '../../profile_list/cubit/sync_cubit.dart';

class ProfileProgressListener extends SyncProgressListener {
  @override
  void onSyncProgressEvent(SyncProgress syncProgress) async {
    final context = App.navState.currentContext!;
    //unawaited to allow profile reload to occur without waiting for sync check to complete
    unawaited(context.read<SyncCubit>().checkSync());
    final profileListBlock = App.navState.currentContext!
        .read<ProfileListBloc>();
    // Reload occurs when sync is successful and profile list is empty to prevent breaking the app when a profile is running
    if (syncProgress.syncStatus == SyncStatus.success &&
        (profileListBlock.state is ProfileListLoaded &&
            (profileListBlock.state as ProfileListLoaded).profiles.isEmpty)) {
      profileListBlock.add(const ProfileListLoadEvent());
      log(
        'ProfileProgressListener: ProfileListLoadEvent triggered to reload profiles',
      );
      unawaited(
        context.read<SyncCubit>().checkSync().whenComplete(
          () => context.read<BackupKeyCubit>().getBackupKeyStatus(),
        ),
      );
    }
  }
}
