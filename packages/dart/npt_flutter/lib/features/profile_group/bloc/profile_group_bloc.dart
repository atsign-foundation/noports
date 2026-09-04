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
  ProfileGroupBloc(this._repo) : super(const ProfileGroupsInitial()) {
    on<ProfileGroupLoadEvent>(_onLoad);
    on<ProfileGroupCreateEvent>(_onCreate);
    on<ProfileGroupRenameEvent>(_onRename);
    on<ProfileGroupDeleteEvent>(_onDelete);
    on<ProfileGroupMoveProfilesEvent>(_onMoveProfiles);
    on<ProfileGroupRemoveProfilesEvent>(_onRemoveProfiles);
    on<ProfileGroupSetSortByTypeEvent>(_onSetSortByType);
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
    emit(ProfileGroupsLoaded(data));
  }

  Future<void> _save(
    ProfileGroupData data,
    Emitter<ProfileGroupState> emit,
  ) async {
    emit(ProfileGroupsLoaded(data));
    try {
      await _repo.putProfileGroups(data);
    } catch (_) {}
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
    final List<ProfileGroup> groups =
        data.groups
            .map((ProfileGroup g) => g.withoutProfiles(event.profileIds))
            .toList()
          ..add(group);

    await _save(data.copyWith(groups: groups), emit);
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
    if (data.groupById(event.groupId) == null) return;

    final List<ProfileGroup> groups = data.groups
        .where((ProfileGroup g) => g.uuid != event.groupId)
        .toList();

    await _save(data.copyWith(groups: groups), emit);
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

    final List<ProfileGroup> groups = data.groups.map((ProfileGroup g) {
      if (g.uuid == event.groupId) {
        return g.withProfiles(event.profileIds);
      }
      return g.withoutProfiles(event.profileIds);
    }).toList();

    await _save(data.copyWith(groups: groups), emit);
  }

  Future<void> _onRemoveProfiles(
    ProfileGroupRemoveProfilesEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;

    final Set<String> toRemove = event.profileIds.toSet();
    final bool affected = data.groups.any(
      (ProfileGroup g) => g.profileIds.any(toRemove.contains),
    );
    if (!affected) return;

    final List<ProfileGroup> groups = data.groups
        .map((ProfileGroup g) => g.withoutProfiles(toRemove))
        .toList();

    await _save(data.copyWith(groups: groups), emit);
  }

  Future<void> _onSetSortByType(
    ProfileGroupSetSortByTypeEvent event,
    Emitter<ProfileGroupState> emit,
  ) async {
    if (state is! ProfileGroupsLoaded) return;
    final ProfileGroupData data = (state as ProfileGroupsLoaded).data;
    if (data.sortByType == event.sortByType) return;

    await _save(data.copyWith(sortByType: event.sortByType), emit);
  }
}
