import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';

part 'profile_folder_event.dart';
part 'profile_folder_state.dart';

class ProfileFolderBloc
    extends LoggingBloc<ProfileFolderEvent, ProfileFolderState> {
  final ProfileFolderRepository _repo;

  /// False after a failed save that couldn't be undone on screen: the next
  /// save then retries even unchanged data.
  bool _persisted = true;

  /// Bumped on load and sign out, so an older session's callbacks drop.
  int _session = 0;

  bool _closing = false;

  final List<ProfileFolderEvent> _deferred = <ProfileFolderEvent>[];

  /// Collapses made before sync caught up; a null key is the unfiled section.
  final Map<String?, bool> _collapsedWhileSyncing = <String?, bool>{};

  /// A caught-up round whose re-read failed still counts for the next one.
  bool _caughtUpSeen = false;

  /// Handles one event at a time, so saves land in the order they were made.
  ProfileFolderBloc(this._repo) : super(const ProfileFoldersInitial()) {
    on<ProfileFolderEvent>(
      _handle,
      transformer: (Stream<ProfileFolderEvent> events, mapper) =>
          events.asyncExpand(mapper),
    );
  }

  Future<void> _handle(
    ProfileFolderEvent event,
    Emitter<ProfileFolderState> emit,
  ) => switch (event) {
    ProfileFolderLoadEvent() => _onLoad(event, emit),
    ProfileFolderRefreshEvent() => _onRefresh(event, emit),
    ProfileFolderCreateEvent() => _onCreate(event, emit),
    ProfileFolderRenameEvent() => _onRename(event, emit),
    ProfileFolderDeleteEvent() => _onDelete(event, emit),
    ProfileFolderMoveProfilesEvent() => _onMoveProfiles(event, emit),
    ProfileFolderRemoveProfilesEvent() => _onRemoveProfiles(event, emit),
    ProfileFolderPlaceProfilesEvent() => _onPlaceProfiles(event, emit),
    ProfileFolderReorderEvent() => _onReorderFolders(event, emit),
    ProfileFolderSetFavoriteEvent() => _onSetFavorite(event, emit),
    ProfileFolderSetCollapsedEvent() => _onSetCollapsed(event, emit),
    ProfileFolderSetSkippedByStartAllEvent() => _onSetSkippedByStartAll(
      event,
      emit,
    ),
  };

  void clearAll() {
    _session++;
    _forgetUnsynced();
    _repo.stopWatching();
    emit(const ProfileFoldersInitial());
  }

  @override
  Future<void> close() {
    _closing = true;
    _session++;
    _repo.stopWatching();
    return super.close();
  }

  void _forgetUnsynced() {
    _deferred.clear();
    _collapsedWhileSyncing.clear();
    _caughtUpSeen = false;
  }

  /// Events made before the local copy caught up are kept for later.
  bool _canEdit(ProfileFolderEvent event) {
    final ProfileFolderState current = state;
    if (current is ProfileFoldersLoaded && !current.synced) {
      _deferred.add(event);
    }
    return current.editable;
  }

  ProfileFolderData _withLocalCollapses(ProfileFolderData data) {
    ProfileFolderData shown = data;
    _collapsedWhileSyncing.forEach((String? id, bool collapsed) {
      shown = shown.withCollapsed(id, collapsed);
    });
    return shown;
  }

  Future<ProfileFolderData?> _read() async {
    try {
      return await _repo.getProfileFolders();
    } catch (_) {
      return null;
    }
  }

  /// Edits wait for the local copy to catch up, so an older copy is never
  /// saved over a newer one.
  Future<void> _onLoad(
    ProfileFolderLoadEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (_closing) return;
    final int session = ++_session;
    _forgetUnsynced();
    _repo.stopWatching();
    emit(const ProfileFoldersLoading());
    final ProfileFolderData? data = await _read();
    if (session != _session) return;
    if (data == null) {
      emit(const ProfileFoldersFailedLoad());
      return;
    }
    _persisted = true;
    emit(ProfileFoldersLoaded(data, synced: false));

    void refresh(bool caughtUp) {
      if (!_closing && session == _session) {
        add(ProfileFolderRefreshEvent(caughtUp: caughtUp));
      }
    }

    _repo.watchSync(refresh);
    unawaited(
      _repo.waitForSync().then((bool caughtUp) {
        if (caughtUp) refresh(true);
      }),
    );
  }

  Future<void> _onRefresh(
    ProfileFolderRefreshEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    final ProfileFolderState current = state;
    if (current is! ProfileFoldersLoaded) return;
    final int session = _session;
    _caughtUpSeen = _caughtUpSeen || event.caughtUp;
    final ProfileFolderData? data = await _read();
    if (data == null || session != _session) return;
    _persisted = true;
    if (current.synced || !_caughtUpSeen) {
      emit(
        ProfileFoldersLoaded(_withLocalCollapses(data), synced: current.synced),
      );
      return;
    }
    final ProfileFolderData shown = _withLocalCollapses(data);
    final List<ProfileFolderEvent> deferred = List<ProfileFolderEvent>.of(
      _deferred,
    );
    _forgetUnsynced();
    if (shown != data) {
      _persisted = false;
      await _save(shown, emit);
    } else {
      emit(ProfileFoldersLoaded(data));
    }
    for (final ProfileFolderEvent deferredEvent in deferred) {
      if (_closing || session != _session) return;
      await _handle(deferredEvent, emit);
    }
  }

  Future<void> _save(
    ProfileFolderData data,
    Emitter<ProfileFolderState> emit,
  ) async {
    final ProfileFolderState current = state;
    if (_persisted && current is ProfileFoldersLoaded && current.data == data) {
      return;
    }
    final int session = _session;
    emit(ProfileFoldersLoaded(data));
    try {
      _persisted = await _repo.putProfileFolders(data);
    } catch (_) {
      _persisted = false;
    }
    if (!_persisted) await _showStoredAfterFailedSave(data, session, emit);
  }

  /// Shows what is stored instead of [edited] and says the save failed,
  /// unless the write landed after all, as a timed out put can.
  Future<void> _showStoredAfterFailedSave(
    ProfileFolderData edited,
    int session,
    Emitter<ProfileFolderState> emit,
  ) async {
    bool signedOut() => _closing || session != _session;
    if (signedOut()) return;
    final ProfileFolderData? stored = await _read();
    if (signedOut()) return;
    if (stored == edited) {
      _persisted = true;
      return;
    }
    if (stored != null) {
      _persisted = true;
      emit(ProfileFoldersLoaded(stored));
    }
    _reportSaveFailed();
  }

  /// Replaces the bar a previous failure left, so failures don't queue up.
  void _reportSaveFailed() {
    final BuildContext? context = App.navState.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    CustomSnackBar.error(
      content: AppLocalizations.of(context)!.folderSaveFailed,
    );
  }

  Future<void> _onCreate(
    ProfileFolderCreateEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    if (data.folderById(event.uuid) != null) return;

    final ProfileFolder folder = ProfileFolder(
      uuid: event.uuid,
      name: event.name,
      profileIds: event.profileIds.toSet().toList(),
    );
    final ProfileFolderData stripped = data.withoutProfilesEverywhere(
      event.profileIds,
    );
    await _save(
      stripped.copyWith(folders: <ProfileFolder>[...stripped.folders, folder]),
      emit,
    );
  }

  Future<void> _onRename(
    ProfileFolderRenameEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    if (data.folderById(event.folderId) == null) return;

    final List<ProfileFolder> folders = data.folders
        .map(
          (ProfileFolder f) =>
              f.uuid == event.folderId ? f.copyWith(name: event.name) : f,
        )
        .toList();

    await _save(data.copyWith(folders: folders), emit);
  }

  /// Unfiles the members while the folder still exists, then drops it.
  Future<void> _onDelete(
    ProfileFolderDeleteEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    final ProfileFolder? deleted = data.folderById(event.folderId);
    if (deleted == null) return;

    final ProfileFolderData unfiled = data.withProfilesUnfiled(
      deleted.profileIds,
      visibleUnfiled: event.visibleUnfiled,
    );
    await _save(
      unfiled.copyWith(
        folders: unfiled.folders
            .where((ProfileFolder f) => f.uuid != event.folderId)
            .toList(),
      ),
      emit,
    );
  }

  Future<void> _onMoveProfiles(
    ProfileFolderMoveProfilesEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    if (event.folderId != null && data.folderById(event.folderId!) == null) {
      return;
    }

    if (event.folderId == null) {
      await _save(
        data.withProfilesUnfiled(
          event.profileIds,
          visibleUnfiled: event.visibleUnfiled,
        ),
        emit,
      );
      return;
    }

    final List<ProfileFolder> folders = data.folders.map((ProfileFolder f) {
      if (f.uuid == event.folderId) {
        return f.withProfiles(event.profileIds);
      }
      return f.withoutProfiles(event.profileIds);
    }).toList();
    final Set<String> moved = event.profileIds.toSet();
    final List<String> unfiled = data.unfiled
        .where((String id) => !moved.contains(id))
        .toList();

    await _save(data.copyWith(folders: folders, unfiled: unfiled), emit);
  }

  Future<void> _onRemoveProfiles(
    ProfileFolderRemoveProfilesEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(data.withoutProfilesEverywhere(event.profileIds), emit);
  }

  Future<void> _onPlaceProfiles(
    ProfileFolderPlaceProfilesEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(
      data.placeProfiles(
        profileIds: event.profileIds,
        folderId: event.folderId,
        sectionOrder: event.sectionOrder,
      ),
      emit,
    );
  }

  Future<void> _onReorderFolders(
    ProfileFolderReorderEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(data.withFoldersOrdered(event.folderIds), emit);
  }

  Future<void> _onSetFavorite(
    ProfileFolderSetFavoriteEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(
      data.copyWith(
        folders: data.folders
            .map(
              (ProfileFolder f) => f.uuid == event.folderId
                  ? f.copyWith(favorite: event.favorite)
                  : f,
            )
            .toList(),
      ),
      emit,
    );
  }

  Future<void> _onSetCollapsed(
    ProfileFolderSetCollapsedEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    final ProfileFolderState current = state;
    if (current is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = current.data.withCollapsed(
      event.folderId,
      event.collapsed,
    );
    if (!current.synced) {
      _collapsedWhileSyncing[event.folderId] = event.collapsed;
      emit(ProfileFoldersLoaded(data, synced: false));
      return;
    }
    await _save(data, emit);
  }

  Future<void> _onSetSkippedByStartAll(
    ProfileFolderSetSkippedByStartAllEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (!_canEdit(event)) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(
      data.copyWith(
        folders: data.folders
            .map(
              (ProfileFolder f) => f.uuid == event.folderId
                  ? f.copyWith(
                      skippedByStartAll: event.skipped
                          .where(f.profileIds.contains)
                          .toSet()
                          .toList(),
                    )
                  : f,
            )
            .toList(),
      ),
      emit,
    );
  }
}
