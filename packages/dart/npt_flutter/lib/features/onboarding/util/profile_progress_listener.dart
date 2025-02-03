import 'dart:async';
import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';

import '../../profile_list/cubit/sync_cubit.dart';

class ProfileProgressListener extends SyncProgressListener {
  @override
  void onSyncProgressEvent(SyncProgress syncProgress) async {
    unawaited(App.navState.currentContext!.read<SyncCubit>().checkSync());
    final profileListBlock = App.navState.currentContext!.read<ProfileListBloc>();

    if (syncProgress.syncStatus == SyncStatus.success &&
        (profileListBlock.state is ProfileListLoaded &&
            (profileListBlock.state as ProfileListLoaded).profiles.isEmpty)) {
      profileListBlock.add(const ProfileListLoadEvent());
      log('ProfileProgressListener: ProfileListLoadEvent triggered to reload profiles');
      unawaited(App.navState.currentContext!.read<SyncCubit>().checkSync());
    }
  }
}
