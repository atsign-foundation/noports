import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_name_dialog.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_picker_dialog.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_start_all_dialog.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/profile_form_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileFolderActions {
  /// The unfiled section as shown, or null before it has loaded.
  static List<String>? visibleUnfiled(BuildContext context) {
    final ProfileFolderState folders = context.read<ProfileFolderBloc>().state;
    final ProfileListState profiles = context.read<ProfileListBloc>().state;
    if (folders is! ProfileFoldersLoaded || profiles is! ProfileListLoaded) {
      return null;
    }
    return folders.data.resolveUnfiled(profiles.profiles);
  }

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

  static Future<void> chooseStartAll(
    BuildContext context,
    ProfileFolder folder,
  ) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileListState profiles = context.read<ProfileListBloc>().state;
    if (!bloc.state.editable || profiles is! ProfileListLoaded) {
      return;
    }
    final Set<String> loaded = profiles.profiles.toSet();
    final List<String> shown = folder.profileIds
        .where(loaded.contains)
        .toList();
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
      builder: (BuildContext _) => ProfileFolderStartAllDialog(
        uuids: shown,
        skipped: folder.skippedByStartAll.toSet(),
      ),
    );
    if (skipped == null) return;
    // Unchecked ones still waiting from an earlier Start all don't start.
    ProfileStartQueue.remove(skipped.where(ProfileStartQueue.isWaiting));
    // Re-read here, not before the dialog, in case a sync changed it.
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolder? current = state.data.folderById(folder.uuid);
    if (current == null) return;
    bloc.add(
      ProfileFolderSetSkippedByStartAllEvent(
        folderId: folder.uuid,
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
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    if (!bloc.state.editable) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          ProfileFolderNameDialog(title: strings.folderNew),
    );
    if (name == null || name.isEmpty) return;
    bloc.add(ProfileFolderCreateEvent(uuid: Uuid.generate(), name: name));
  }

  static Future<void> renameFolder(
    BuildContext context,
    ProfileFolder folder,
  ) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    if (!bloc.state.editable) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => ProfileFolderNameDialog(
        title: strings.folderRenameTitle,
        initialName: folder.name,
      ),
    );
    if (name == null || name.isEmpty || name == folder.name) return;
    bloc.add(ProfileFolderRenameEvent(folderId: folder.uuid, name: name));
  }

  /// Asks the user which folder [profileIds] should live in, then applies it.
  /// Returns false if the user cancelled.
  static Future<bool> moveToFolder(
    BuildContext context,
    Iterable<String> profileIds,
  ) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded || !state.editable) return false;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<String> ids = profileIds.toList();
    if (ids.isEmpty) return false;

    final ProfileFolderPick? pick = await showDialog<ProfileFolderPick>(
      context: context,
      builder: (BuildContext _) => ProfileFolderPickerDialog(
        folders: state.folders,
        currentFolderId: ids.length == 1
            ? state.data.folderForProfile(ids.first)?.uuid
            : null,
      ),
    );
    if (pick == null) return false;

    switch (pick) {
      case ProfileFolderPickNone():
        bloc.add(
          ProfileFolderMoveProfilesEvent(
            profileIds: ids,
            folderId: null,
            // Re-read here, not before the dialog, in case a sync changed it.
            visibleUnfiled: context.mounted ? visibleUnfiled(context) : null,
          ),
        );
      case ProfileFolderPickExisting(:final String folderId):
        bloc.add(
          ProfileFolderMoveProfilesEvent(profileIds: ids, folderId: folderId),
        );
      case ProfileFolderPickNew():
        if (!context.mounted) return false;
        final String? name = await showDialog<String>(
          context: context,
          builder: (BuildContext _) =>
              ProfileFolderNameDialog(title: strings.folderNew),
        );
        if (name == null || name.isEmpty) return false;
        bloc.add(
          ProfileFolderCreateEvent(
            uuid: Uuid.generate(),
            name: name,
            profileIds: ids,
          ),
        );
    }
    return true;
  }

  static void addConnectionToFolder(String folderId) {
    final String uuid = Uuid.generate();
    wrapperNav.currentState?.pushNamed(
      HomeRoutes.profileForm,
      arguments: ProfileFormPageArguments(uuid, folderId: folderId),
    );
  }
}
