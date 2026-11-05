import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_name_dialog.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_picker_dialog.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_start_all_dialog.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/profile_form_page.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileFolderActions {
  /// Read when a dialog is confirmed, not when it opens: a sync can change it.
  static List<String>? visibleUnfiled(BuildContext context) {
    final ProfileFolderState folders = context.read<ProfileFolderBloc>().state;
    final ProfileListState profiles = context.read<ProfileListBloc>().state;
    if (folders is! ProfileFoldersLoaded || profiles is! ProfileListLoaded) {
      return null;
    }
    return folders.data.resolveUnfiled(profiles.profiles);
  }

  static void startAll(BuildContext context, Iterable<String> uuids) {
    context.read<ProfileStartQueueCubit>().add(uuids);
  }

  static void stopAll(BuildContext context, Iterable<String> uuids) {
    context.read<ProfileStartQueueCubit>().remove(uuids);
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    for (final String uuid in uuids) {
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      if (_isStoppable(bloc.state)) bloc.add(const ProfileStopEvent());
    }
  }

  /// Whether [stopAll] has anything among [uuids] to stop or to take out of
  /// the start queue.
  static bool canStopAll(BuildContext context, Iterable<String> uuids) {
    final Map<String, Object?> running = context
        .read<ProfilesRunningCubit>()
        .state
        .socketConnectors;
    final ProfileStartQueueCubit queue = context.read<ProfileStartQueueCubit>();
    final ProfileCacheCubit cache = context.read<ProfileCacheCubit>();
    return uuids.any(
      (String uuid) =>
          running.containsKey(uuid) ||
          queue.isWaiting(uuid) ||
          _isStoppable(cache.getProfileBloc(uuid).state),
    );
  }

  /// Connecting and waiting to retry count too, as a row's stop does.
  static bool _isStoppable(ProfileState state) =>
      state is ProfileStarted || state is ProfileStarting;

  static Future<void> chooseStartAll(
    BuildContext context,
    ProfileFolder folder,
  ) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileStartQueueCubit queue = context.read<ProfileStartQueueCubit>();
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
    final Iterable<String> uncheckedStillWaiting = skipped.where(
      queue.isWaiting,
    );
    queue.remove(uncheckedStillWaiting);
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolder? current = state.data.folderById(folder.uuid);
    if (current == null) return;
    final Iterable<String> skippedUnlisted = current.skippedByStartAll.where(
      (String uuid) => !shown.contains(uuid),
    );
    bloc.add(
      ProfileFolderSetSkippedByStartAllEvent(
        folderId: folder.uuid,
        skipped: <String>[...skippedUnlisted, ...skipped],
      ),
    );
  }

  static Future<void> createFolder(BuildContext context) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded || !state.editable) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => ProfileFolderNameDialog(
        title: strings.folderNew,
        takenNames: state.folders.map((ProfileFolder f) => f.name),
      ),
    );
    if (name == null || name.isEmpty) return;
    bloc.add(ProfileFolderCreateEvent(uuid: Uuid.generate(), name: name));
  }

  static Future<void> renameFolder(
    BuildContext context,
    ProfileFolder folder,
  ) async {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded || !state.editable) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => ProfileFolderNameDialog(
        title: strings.folderRenameTitle,
        initialName: folder.name,
        takenNames: state.folders
            .where((ProfileFolder f) => f.uuid != folder.uuid)
            .map((ProfileFolder f) => f.name),
      ),
    );
    if (name == null || name.isEmpty || name == folder.name) return;
    bloc.add(ProfileFolderRenameEvent(folderId: folder.uuid, name: name));
  }

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

    final Set<String?> current = <String?>{
      for (final String id in ids) state.data.folderForProfile(id)?.uuid,
    };
    final ProfileFolderPick? pick = await showDialog<ProfileFolderPick>(
      context: context,
      builder: (BuildContext _) => ProfileFolderPickerDialog(
        folders: state.folders,
        currentFolderId: current.length == 1 ? current.single : null,
        hasCurrent: current.length == 1,
      ),
    );
    if (pick == null) return false;

    switch (pick) {
      case ProfileFolderPickUnfiled():
        bloc.add(
          ProfileFolderMoveProfilesEvent(
            profileIds: ids,
            folderId: null,
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
          builder: (BuildContext _) => ProfileFolderNameDialog(
            title: strings.folderNew,
            takenNames: state.folders.map((ProfileFolder f) => f.name),
          ),
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
