import 'dart:async';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';

part 'profile_list_event.dart';
part 'profile_list_state.dart';

class ProfileListBloc extends LoggingBloc<ProfileListEvent, ProfileListState> {
  final ProfileRepository _repo;
  final ProfileCacheCubit _profileCacheCubit;
  ProfileListBloc(this._repo, this._profileCacheCubit)
    : super(const ProfileListInitial()) {
    on<ProfileListLoadEvent>(_onLoad);
    on<ProfileListUpdateEvent>(_onUpdate);
    on<ProfileListDeleteEvent>(_onDelete);
    on<ProfileListAddEvent>(_onAdd);
    on<ProfileListSortEvent>(_onSort);
  }

  void clearAll() => emit(const ProfileListInitial());

  Future<void> _onLoad(
    ProfileListLoadEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    emit(const ProfileListLoading());

    Iterable<String>? profiles;
    try {
      profiles = await _repo.getProfileUuids();
    } catch (_) {
      profiles = null;
    }

    if (profiles == null) {
      emit(const ProfileListFailedLoad());
      return;
    }

    emit(ProfileListLoaded(profiles: profiles));
  }

  Future<void> _onUpdate(
    ProfileListUpdateEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    emit(ProfileListLoaded(profiles: event.profiles));
  }

  Future<void> _onDelete(
    ProfileListDeleteEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    // Don't allow deletes unless listed is loaded - this reduces the number of edge cases significantly
    if (state is! ProfileListLoaded) {
      return;
    }
    var profiles = (state as ProfileListLoaded).profiles;

    emit(
      ProfileListLoaded(
        profiles: profiles.where(
          (profile) => !event.toDelete.contains(profile),
        ),
      ),
    );
    var bloc = App.navState.currentContext?.read<FavoriteBloc>();
    var favoritesToRemove = <Favorite>[];
    var loadedFavorites = <Favorite>[];
    if (bloc != null && bloc.state is FavoritesLoaded) {
      loadedFavorites = (bloc.state as FavoritesLoaded).favorites.toList();
    }
    for (final uuid in event.toDelete) {
      for (final fav in loadedFavorites) {
        if (fav.containsProfile(uuid)) favoritesToRemove.add(fav);
      }
      unawaited(_repo.deleteProfile(uuid));
    }
    bloc?.add(FavoriteRemoveEvent(favoritesToRemove));
  }

  Future<void> _onAdd(
    ProfileListAddEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    // Don't allow async bulk adds unless listed is loaded - this reduces the number of edge cases significantly
    if (state is! ProfileListLoaded) {
      return;
    }

    var profiles = (state as ProfileListLoaded).profiles.toList();
    for (var profile in event.toAdd) {
      App.log('ProfileListAdd  | putProfile($profile)'.loggable);
      unawaited(_repo.putProfile(profile));
      profiles.add(profile.uuid);
    }

    emit(ProfileListLoaded(profiles: profiles));
  }

  Future<void> _onSort(
    ProfileListSortEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    App.log('Sort event received: column=${event.sortColumn}'.loggable);
    // Don't allow sorts unless listed is loaded - this reduces the number of edge cases significantly
    if (state is! ProfileListLoaded) {
      App.log('Cannot sort - state is not ProfileListLoaded'.loggable);
      return;
    }
    var currentState = state as ProfileListLoaded;
    App.log(
      'Current sort: column=${currentState.sortColumn}, order=${currentState.sortOrder}'
          .loggable,
    );
    // Toggle sort order if clicking same column
    final newSortOrder =
        currentState.sortColumn == event.sortColumn &&
            currentState.sortOrder == SortOrder.ascending
        ? SortOrder.descending
        : SortOrder.ascending;

    App.log(
      'New sort: column=${event.sortColumn}, order=$newSortOrder'.loggable,
    );

    // Sort the profile by the selected column
    final sortedProfiles = await _sortProfiles(
      // currentState.profiles,
      event.sortColumn,
      newSortOrder,
    );

    App.log('Sorted ${sortedProfiles.length} profiles'.loggable);
    emit(
      currentState.copyWith(
        profiles: sortedProfiles,
        sortColumn: event.sortColumn,
        sortOrder: newSortOrder,
      ),
    );
  }

  // Helper function to sort profiles based on column and order
  Future<List<String>> _sortProfiles(
    // Iterable<String> profileUuids,
    SortColumn sortColumn,
    SortOrder sortOrder,
  ) async {
    var profileBlocList = _profileCacheCubit.state.profileBlocs.values.toList();
    if (sortColumn == SortColumn.none) {
      App.log('No sorting applied (SortColumn.none)'.loggable);
      return profileBlocList.map((e) => e.uuid).toList();
    }

    final profileDataList = profileBlocList.map((profileBloc) {
      final profileState = profileBloc.state;

      if (profileState is ProfileLoadedState) {
        App.log('Got profile ${profileState.uuid} for sorting'.loggable);
        return (
          uuid: profileState.uuid,
          profile: profileState.profile,
          state: profileState,
        );
      } else {
        App.log(
          'Failed to get profile ${profileState.uuid} for sorting: ${profileState.runtimeType}'
              .loggable,
        );
        return (uuid: profileState.uuid, profile: null, state: profileState);
      }
    }).toList();

    // Sort based on column
    profileDataList.sort((a, b) {
      if (a.profile == null || b.profile == null) return 0;

      int comparison = 0;

      switch (sortColumn) {
        case SortColumn.profileName:
          comparison = a.profile!.displayName.compareTo(b.profile!.displayName);
          break;
        case SortColumn.deviceName:
          comparison = a.profile!.deviceName.compareTo(b.profile!.deviceName);
          break;
        case SortColumn.serviceMapping:
          final aComparator =
              '${a.profile!.localPort}:${a.profile!.remoteHost}:${a.profile!.remotePort}';
          final bComparator =
              '${b.profile!.localPort}:${b.profile!.remoteHost}:${b.profile!.remotePort}';
          comparison = aComparator.compareTo(bComparator);
          break;
        case SortColumn.status:
          log(
            'Comparing status: ${_getStatusPriority(a.state)} ${a.state.runtimeType} vs ${_getStatusPriority(b.state)} ${b.state.runtimeType}',
          );
          comparison = _getStatusPriority(
            a.state,
          ).compareTo(_getStatusPriority(b.state));
          break;
        case SortColumn.none:
          comparison = 0;
          break;
      }

      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return profileDataList.map((e) => e.uuid).toList();
  }

  /// helper method to assign priority to each state for meaningful sorting
  int _getStatusPriority(ProfileState state) {
    return switch (state) {
      ProfileFailedLoad _ => 0,
      ProfileFailedStart _ => 0,
      ProfileFailedSave _ => 0,
      ProfileStarted _ => 1,
      ProfileStarting _ => 1,
      ProfileStopping _ => 2,
      ProfileLoaded _ => 3,
      ProfileLoading _ => 4,
      ProfileInitial _ => 5,
    };
  }
}
