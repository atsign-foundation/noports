import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/repository/profile_group_repository.dart';
import 'package:npt_flutter/util/uuid.dart';

part 'profile_group_event.dart';
part 'profile_group_state.dart';

class ProfileGroupBloc
    extends LoggingBloc<ProfileGroupEvent, ProfileGroupState> {
  final ProfileGroupRepository _repo;

  /// False after a failed save, so the next save retries even if the data
  /// hasn't changed.
  bool _persisted = true;

  ProfileGroupBloc(this._repo) : super(const ProfileGroupsInitial()) {
    on<ProfileGroupLoadEvent>(_onLoad);
    on<ProfileGroupCreateEvent>(_onCreate);
    on<ProfileGroupRenameEvent>(_onRename);
    on<ProfileGroupDeleteEvent>(_onDelete);
    on<ProfileGroupMoveProfilesEvent>(_onMoveProfiles);
    on<ProfileGroupRemoveProfilesEvent>(_onRemoveProfiles);
    on<ProfileGroupPlaceProfilesEvent>(_onPlaceProfiles);
    on<ProfileGroupReorderFoldersEvent>(_onReorderFolders);
  }

  void clearAll() => emit(const ProfileGroupsInitial());

  Future<void> _onLoad(
    ProfileGroupLoadEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    emit(const ProfileGroupsLoading());

    ProfileGroupData? data;
    try {
      data = await _repo.getProfileGroups();
    } catch (_) {
      data = null;
    }

    if (data == null) {
      emit(const ProfileGroupsFailedLoad());
      return;
    }
    _persisted = true;
    emit(ProfileGroupsLoaded(data));
  }

  Future<void> _save(
    ProfileGroupData data,
    Emitter<ProfileGroupState> emit,
  ) async {
    final ProfileGroupState current = state;
    if (_persisted && current is ProfileGroupsLoaded && current.data == data) {
      return;
    }
    emit(ProfileGroupsLoaded(data));
    try {
      _persisted = await _repo.putProfileGroups(data);
    } catch (_) {
      _persisted = false;
    }
  }

  Future<void> _onCreate(
    ProfileGroupCreateEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;

    final ProfileGroup group = ProfileGroup(
      uuid: Uuid.generate(),
      name: event.name,
      profileIds: event.profileIds.toSet().toList(),
    );
    final ProfileGroupData stripped = data.withoutProfilesEverywhere(
      event.profileIds,
    );
    await _save(
      stripped.copyWith(groups: <ProfileGroup>[...stripped.groups, group]),
      emit,
    );
  }

  Future<void> _onRename(
    ProfileGroupRenameEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;
    if (data.groupById(event.groupId) == null) return;

    final List<ProfileGroup> groups = data.groups
        .map(
          (ProfileGroup g) =>
              g.uuid == event.groupId ? g.copyWith(name: event.name) : g,
        )
        .toList();

    await _save(data.copyWith(groups: groups), emit);
  }

  Future<void> _onDelete(
    ProfileGroupDeleteEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;
    final ProfileGroup? deleted = data.groupById(event.groupId);
    if (deleted == null) return;

    // Ungroup the members while the folder still exists, then drop it.
    final ProfileGroupData ungrouped = data.withProfilesUngrouped(
      deleted.profileIds,
      visibleUngrouped: event.visibleUngrouped,
    );
    await _save(
      ungrouped.copyWith(
        groups: ungrouped.groups
            .where((ProfileGroup g) => g.uuid != event.groupId)
            .toList(),
      ),
      emit,
    );
  }

  Future<void> _onMoveProfiles(
    ProfileGroupMoveProfilesEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;
    if (event.groupId != null && data.groupById(event.groupId!) == null) {
      return;
    }

    if (event.groupId == null) {
      await _save(
        data.withProfilesUngrouped(
          event.profileIds,
          visibleUngrouped: event.visibleUngrouped,
        ),
        emit,
      );
      return;
    }

    final List<ProfileGroup> groups = data.groups.map((ProfileGroup g) {
      if (g.uuid == event.groupId) {
        return g.withProfiles(event.profileIds);
      }
      return g.withoutProfiles(event.profileIds);
    }).toList();
    final Set<String> moved = event.profileIds.toSet();
    final List<String> ungrouped = data.ungrouped
        .where((String id) => !moved.contains(id))
        .toList();

    await _save(data.copyWith(groups: groups, ungrouped: ungrouped), emit);
  }

  Future<void> _onRemoveProfiles(
    ProfileGroupRemoveProfilesEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;

    await _save(data.withoutProfilesEverywhere(event.profileIds), emit);
  }

  Future<void> _onPlaceProfiles(
    ProfileGroupPlaceProfilesEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;

    await _save(
      data.placeProfiles(
        profileIds: event.profileIds,
        groupId: event.groupId,
        sectionOrder: event.sectionOrder,
      ),
      emit,
    );
  }

  Future<void> _onReorderFolders(
    ProfileGroupReorderFoldersEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;

    await _save(data.withFoldersOrdered(event.groupIds), emit);
  }
}
