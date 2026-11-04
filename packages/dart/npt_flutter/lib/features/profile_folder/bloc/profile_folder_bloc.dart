import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';

part 'profile_folder_event.dart';
part 'profile_folder_state.dart';

class ProfileFolderBloc
    extends LoggingBloc<ProfileFolderEvent, ProfileFolderState> {
  final ProfileFolderRepository _repo;

  /// False after a failed save, so the next save retries unchanged data.
  bool _persisted = true;

  /// Bumped on load and sign out, so a superseded load doesn't emit.
  int _session = 0;

  /// A refresh that raced a save is dropped instead of reverting it.
  int _saving = 0;
  int _saves = 0;

  ProfileFolderBloc(this._repo) : super(const ProfileFoldersInitial()) {
    on<ProfileFolderLoadEvent>(_onLoad);
    on<ProfileFolderRefreshEvent>(_onRefresh);
    on<ProfileFolderCreateEvent>(_onCreate);
    on<ProfileFolderRenameEvent>(_onRename);
    on<ProfileFolderDeleteEvent>(_onDelete);
    on<ProfileFolderMoveProfilesEvent>(_onMoveProfiles);
    on<ProfileFolderRemoveProfilesEvent>(_onRemoveProfiles);
    on<ProfileFolderPlaceProfilesEvent>(_onPlaceProfiles);
    on<ProfileFolderReorderEvent>(_onReorderFolders);
    on<ProfileFolderSetFavoriteEvent>(_onSetFavorite);
    on<ProfileFolderSetCollapsedEvent>(_onSetCollapsed);
    on<ProfileFolderSetSkippedByStartAllEvent>(_onSetSkippedByStartAll);
  }

  void clearAll() {
    _session++;
    _repo.stopWatching();
    emit(const ProfileFoldersInitial());
  }

  @override
  Future<void> close() {
    _session++;
    _repo.stopWatching();
    return super.close();
  }

  Future<void> _onLoad(
    ProfileFolderLoadEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    final int session = ++_session;
    emit(const ProfileFoldersLoading());

    ProfileFolderData? data;
    bool synced = true;
    try {
      // A copy older than the atServer's must not be shown and saved over it.
      synced = await _repo.waitForSync();
      if (synced) {
        if (session != _session) return;
        data = await _repo.getProfileFolders();
      }
    } catch (_) {
      data = null;
    }
    if (session != _session) return;

    if (data == null) {
      emit(const ProfileFoldersFailedLoad());
      if (!synced) {
        _repo.watchSync(() {
          if (!isClosed && state is ProfileFoldersFailedLoad) {
            add(const ProfileFolderLoadEvent());
          }
        }, caughtUpOnly: true);
      }
      return;
    }
    _persisted = true;
    emit(ProfileFoldersLoaded(data));
    _repo.watchSync(() {
      if (!isClosed) add(const ProfileFolderRefreshEvent());
    });
  }

  Future<void> _onRefresh(
    ProfileFolderRefreshEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded || _saving > 0) return;
    final int session = _session;
    final int saves = _saves;

    ProfileFolderData? data;
    try {
      data = await _repo.getProfileFolders();
    } catch (_) {
      data = null;
    }
    if (data == null || session != _session || saves != _saves) return;
    if (state is! ProfileFoldersLoaded) return;
    _persisted = true;
    emit(ProfileFoldersLoaded(data));
  }

  Future<void> _save(
    ProfileFolderData data,
    Emitter<ProfileFolderState> emit,
  ) async {
    final ProfileFolderState current = state;
    if (_persisted && current is ProfileFoldersLoaded && current.data == data) {
      return;
    }
    emit(ProfileFoldersLoaded(data));
    _saves++;
    _saving++;
    try {
      _persisted = await _repo.putProfileFolders(data);
    } catch (_) {
      _persisted = false;
    } finally {
      _saving--;
    }
  }

  Future<void> _onCreate(
    ProfileFolderCreateEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
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
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    if (data.folderById(event.folderId) == null) return;

    final List<ProfileFolder> folders = data.folders
        .map(
          (ProfileFolder g) =>
              g.uuid == event.folderId ? g.copyWith(name: event.name) : g,
        )
        .toList();

    await _save(data.copyWith(folders: folders), emit);
  }

  Future<void> _onDelete(
    ProfileFolderDeleteEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;
    final ProfileFolder? deleted = data.folderById(event.folderId);
    if (deleted == null) return;

    // Unfile the members while the folder still exists, then drop it.
    final ProfileFolderData unfiled = data.withProfilesUnfiled(
      deleted.profileIds,
      visibleUnfiled: event.visibleUnfiled,
    );
    await _save(
      unfiled.copyWith(
        folders: unfiled.folders
            .where((ProfileFolder g) => g.uuid != event.folderId)
            .toList(),
      ),
      emit,
    );
  }

  Future<void> _onMoveProfiles(
    ProfileFolderMoveProfilesEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
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

    final List<ProfileFolder> folders = data.folders.map((ProfileFolder g) {
      if (g.uuid == event.folderId) {
        return g.withProfiles(event.profileIds);
      }
      return g.withoutProfiles(event.profileIds);
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
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(data.withoutProfilesEverywhere(event.profileIds), emit);
  }

  Future<void> _onPlaceProfiles(
    ProfileFolderPlaceProfilesEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
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
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(data.withFoldersOrdered(event.folderIds), emit);
  }

  Future<void> _onSetFavorite(
    ProfileFolderSetFavoriteEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(
      data.copyWith(
        folders: data.folders
            .map(
              (ProfileFolder g) => g.uuid == event.folderId
                  ? g.copyWith(favorite: event.favorite)
                  : g,
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
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    if (event.folderId == null) {
      await _save(data.copyWith(unfiledCollapsed: event.collapsed), emit);
      return;
    }
    await _save(
      data.copyWith(
        folders: data.folders
            .map(
              (ProfileFolder g) => g.uuid == event.folderId
                  ? g.copyWith(collapsed: event.collapsed)
                  : g,
            )
            .toList(),
      ),
      emit,
    );
  }

  Future<void> _onSetSkippedByStartAll(
    ProfileFolderSetSkippedByStartAllEvent event,
    Emitter<ProfileFolderState> emit,
  ) async {
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = (state as ProfileFoldersLoaded).data;

    await _save(
      data.copyWith(
        folders: data.folders
            .map(
              (ProfileFolder g) => g.uuid == event.folderId
                  ? g.copyWith(
                      skippedByStartAll: event.skipped
                          .where(g.profileIds.contains)
                          .toSet()
                          .toList(),
                    )
                  : g,
            )
            .toList(),
      ),
      emit,
    );
  }
}
