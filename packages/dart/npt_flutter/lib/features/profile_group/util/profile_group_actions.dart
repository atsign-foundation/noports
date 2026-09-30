import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_name_dialog.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_picker_dialog.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_start_all_dialog.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/profile_form_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileGroupActions {
  /// The ungrouped section as the connections list currently shows it, so
  /// moved-out profiles land at the end. Null if it isn't available yet.
  static List<String>? visibleUngrouped(BuildContext context) {
    final ProfileGroupState groups = context.read<ProfileGroupBloc>().state;
    final ProfileListState profiles = context.read<ProfileListBloc>().state;
    if (groups is! ProfileGroupsLoaded || profiles is! ProfileListLoaded) {
      return null;
    }
    return groups.data.resolveUngrouped(profiles.profiles);
  }

  /// Starts one connection at a time: started together, several of them can
  /// time out waiting for their device to answer.
  static void startAll(BuildContext context, Iterable<String> uuids) {
    ProfileStartQueue.add(context.read<ProfileCacheCubit>(), uuids);
  }

  static void stopAll(BuildContext context, Iterable<String> uuids) {
    ProfileStartQueue.remove(uuids);
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    for (final String uuid in uuids) {
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      if (bloc.state is ProfileStarted) {
        bloc.add(const ProfileStopEvent());
      }
    }
  }

  /// Asks which connections of [group] Start all starts, and saves it.
  static Future<void> chooseStartAll(
    BuildContext context,
    ProfileGroup group,
  ) async {
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    final ProfileListState profiles = context.read<ProfileListBloc>().state;
    if (bloc.state is! ProfileGroupsLoaded || profiles is! ProfileListLoaded) {
      return;
    }
    final Set<String> loaded = profiles.profiles.toSet();
    final List<String> shown = group.profileIds.where(loaded.contains).toList();
    if (shown.isEmpty) return;
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    for (final String uuid in shown) {
      final ProfileBloc profile = cache.getProfileBloc(uuid);
      if (profile.state is ProfileInitial) {
        profile.add(const ProfileLoadEvent());
      }
    }

    final Set<String>? skipped = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext _) => ProfileGroupStartAllDialog(
        uuids: shown,
        skipped: group.skippedByStartAll.toSet(),
      ),
    );
    if (skipped == null) return;
    // Unchecked while waiting for an earlier Start all: not started either.
    ProfileStartQueue.remove(skipped.where(ProfileStartQueue.isWaiting));
    // Re-read here, not before the dialog, in case a sync changed it.
    final ProfileGroupState state = bloc.state;
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroup? current = state.data.groupById(group.uuid);
    if (current == null) return;
    bloc.add(
      ProfileGroupSetSkippedByStartAllEvent(
        groupId: group.uuid,
        skipped: <String>[
          // Members not listed keep what they had.
          ...current.skippedByStartAll.where(
            (String uuid) => !shown.contains(uuid),
          ),
          ...skipped,
        ],
      ),
    );
  }

  static Future<void> createFolder(BuildContext context) async {
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    if (bloc.state is! ProfileGroupsLoaded) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          ProfileGroupNameDialog(title: strings.groupNewFolder),
    );
    if (name == null || name.isEmpty) return;
    bloc.add(ProfileGroupCreateEvent(name: name));
  }

  static Future<void> renameFolder(
    BuildContext context,
    ProfileGroup group,
  ) async {
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    if (bloc.state is! ProfileGroupsLoaded) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => ProfileGroupNameDialog(
        title: strings.groupRenameFolder,
        initialName: group.name,
      ),
    );
    if (name == null || name.isEmpty || name == group.name) return;
    bloc.add(ProfileGroupRenameEvent(groupId: group.uuid, name: name));
  }

  /// Asks the user which folder [profileIds] should live in, then applies it.
  /// Returns false if the user cancelled.
  static Future<bool> moveToFolder(
    BuildContext context,
    Iterable<String> profileIds,
  ) async {
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    final ProfileGroupState state = bloc.state;
    if (state is! ProfileGroupsLoaded) return false;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<String> ids = profileIds.toList();
    if (ids.isEmpty) return false;

    final ProfileGroupPick? pick = await showDialog<ProfileGroupPick>(
      context: context,
      builder: (BuildContext _) => ProfileGroupPickerDialog(
        groups: state.groups,
        currentGroupId: ids.length == 1
            ? state.data.groupForProfile(ids.first)?.uuid
            : null,
      ),
    );
    if (pick == null) return false;

    switch (pick) {
      case ProfileGroupPickNone():
        bloc.add(
          ProfileGroupMoveProfilesEvent(
            profileIds: ids,
            groupId: null,
            // Re-read here, not before the dialog, in case a sync changed it.
            visibleUngrouped: context.mounted
                ? visibleUngrouped(context)
                : null,
          ),
        );
      case ProfileGroupPickExisting(:final String groupId):
        bloc.add(
          ProfileGroupMoveProfilesEvent(profileIds: ids, groupId: groupId),
        );
      case ProfileGroupPickNew():
        if (!context.mounted) return false;
        final String? name = await showDialog<String>(
          context: context,
          builder: (BuildContext _) =>
              ProfileGroupNameDialog(title: strings.groupNewFolder),
        );
        if (name == null || name.isEmpty) return false;
        bloc.add(ProfileGroupCreateEvent(name: name, profileIds: ids));
    }
    return true;
  }

  static void addConnectionToFolder(String groupId) {
    final String uuid = Uuid.generate();
    wrapperNav.currentState?.pushNamed(
      HomeRoutes.profileForm,
      arguments: ProfileFormPageArguments(uuid, groupId: groupId),
    );
  }
}
