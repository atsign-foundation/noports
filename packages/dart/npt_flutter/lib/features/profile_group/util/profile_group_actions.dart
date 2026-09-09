import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_name_dialog.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_picker_dialog.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/profile_form_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileGroupActions {
  static void startAll(BuildContext context, Iterable<String> uuids) {
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    for (final String uuid in uuids) {
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      switch (bloc.state) {
        case ProfileLoaded _:
        case ProfileFailedSave _:
        case ProfileFailedStart _:
          bloc.add(const ProfileStartEvent());
        default:
          break;
      }
    }
  }

  static void stopAll(BuildContext context, Iterable<String> uuids) {
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    for (final String uuid in uuids) {
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      if (bloc.state is ProfileStarted) {
        bloc.add(const ProfileStopEvent());
      }
    }
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
  static Future<void> moveToFolder(
    BuildContext context,
    Iterable<String> profileIds,
  ) async {
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    final ProfileGroupState state = bloc.state;
    if (state is! ProfileGroupsLoaded) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<String> ids = profileIds.toList();
    if (ids.isEmpty) return;

    final ProfileGroupPick? pick = await showDialog<ProfileGroupPick>(
      context: context,
      builder: (BuildContext _) => ProfileGroupPickerDialog(
        groups: state.groups,
        currentGroupId: ids.length == 1
            ? state.data.groupForProfile(ids.first)?.uuid
            : null,
      ),
    );
    if (pick == null) return;

    switch (pick) {
      case ProfileGroupPickNone():
        bloc.add(ProfileGroupMoveProfilesEvent(profileIds: ids, groupId: null));
      case ProfileGroupPickExisting(:final String groupId):
        bloc.add(
          ProfileGroupMoveProfilesEvent(profileIds: ids, groupId: groupId),
        );
      case ProfileGroupPickNew():
        if (!context.mounted) return;
        final String? name = await showDialog<String>(
          context: context,
          builder: (BuildContext _) =>
              ProfileGroupNameDialog(title: strings.groupNewFolder),
        );
        if (name == null || name.isEmpty) return;
        bloc.add(ProfileGroupCreateEvent(name: name, profileIds: ids));
    }
  }

  static void addConnectionToFolder(String groupId) {
    final String uuid = Uuid.generate();
    wrapperNav.currentState?.pushNamed(
      HomeRoutes.profileForm,
      arguments: ProfileFormPageArguments(uuid, groupId: groupId),
    );
  }
}
