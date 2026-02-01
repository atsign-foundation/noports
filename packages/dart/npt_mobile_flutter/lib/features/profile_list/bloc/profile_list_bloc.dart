import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/favorite/favorite.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';

part 'profile_list_event.dart';
part 'profile_list_state.dart';

class ProfileListBloc extends LoggingBloc<ProfileListEvent, ProfileListState> {
  final ProfileRepository _repo;
  ProfileListBloc(this._repo) : super(const ProfileListInitial()) {
    on<ProfileListLoadEvent>(_onLoad);
    on<ProfileListUpdateEvent>(_onUpdate);
    on<ProfileListDeleteEvent>(_onDelete);
    on<ProfileListAddEvent>(_onAdd);
  }

  void clearAll() => emit(const ProfileListInitial());

  /// Sorts profile UUIDs: favorited profiles alphabetically first, then non-favorited alphabetically
  Future<Iterable<String>> _sortProfiles(Iterable<String> profileUuids) async {
    // Get favorites from context
    final context = App.navState.currentContext;
    if (context == null) {
      App.log(
        '[ProfileListBloc] No context available for sorting, returning unsorted'
            .loggable,
      );
      return profileUuids;
    }

    final favoriteBloc = context.read<FavoriteBloc>();
    final favoriteState = favoriteBloc.state;

    Set<String> favoritedUuids = {};
    if (favoriteState is FavoritesLoaded) {
      for (var fav in favoriteState.favorites) {
        favoritedUuids.addAll(fav.profileIds);
      }
      App.log(
        '[ProfileListBloc] Found ${favoritedUuids.length} favorited profiles'
            .loggable,
      );
    }

    // Fetch all profiles to get their display names
    try {
      App.log(
        '[ProfileListBloc] Fetching ${profileUuids.length} profiles for sorting...'
            .loggable,
      );
      final profiles = await _repo.getProfiles(profileUuids);
      final profileMap = {for (var p in profiles) p.uuid: p};
      App.log(
        '[ProfileListBloc] Fetched ${profileMap.length} profiles successfully'
            .loggable,
      );

      // Split into favorited and non-favorited
      final favorited = <Profile>[];
      final nonFavorited = <Profile>[];

      for (var uuid in profileUuids) {
        final profile = profileMap[uuid];
        if (profile == null) {
          App.log(
            '[ProfileListBloc] Warning: Profile $uuid not found in map'
                .loggable,
          );
          continue;
        }

        if (favoritedUuids.contains(uuid)) {
          favorited.add(profile);
        } else {
          nonFavorited.add(profile);
        }
      }

      App.log(
        '[ProfileListBloc] Split into ${favorited.length} favorited and ${nonFavorited.length} non-favorited'
            .loggable,
      );

      // Sort both groups alphabetically by displayName (case-insensitive)
      favorited.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      nonFavorited.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      // Combine: favorited first, then non-favorited
      return [
        ...favorited.map((p) => p.uuid),
        ...nonFavorited.map((p) => p.uuid),
      ];
    } catch (e, st) {
      App.log('[ERROR] Failed to sort profiles: $e'.loggable);
      App.log('[ERROR] Stack trace: $st'.loggable);
      // Return unsorted on error
      return profileUuids;
    }
  }

  Future<void> _onLoad(
    ProfileListLoadEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    emit(const ProfileListLoading());

    App.log('[ProfileListBloc] Loading profiles...'.loggable);

    Iterable<String>? profiles;
    try {
      // Try fetching from remote secondary first for faster initial load
      // This is especially useful after APKAM enrollment when local secondary
      // hasn't synced yet
      App.log(
        '[ProfileListBloc] Fetching profiles with preferRemote=true'.loggable,
      );
      profiles = await _repo.getProfileUuids(preferRemote: true);
      App.log(
        '[ProfileListBloc] Fetched ${profiles?.length ?? 0} profile UUIDs'
            .loggable,
      );
    } catch (e, st) {
      App.log('[ERROR] ProfileListBloc failed to fetch profiles: $e'.loggable);
      App.log('[ERROR] Stack trace: $st'.loggable);
      profiles = null;
    }

    if (profiles == null) {
      App.log(
        '[ProfileListBloc] Profiles is null, emitting ProfileListFailedLoad'
            .loggable,
      );
      emit(const ProfileListFailedLoad());
      return;
    }

    // Sort profiles: favorited alphabetically, then non-favorited alphabetically
    App.log(
      '[ProfileListBloc] Sorting ${profiles.length} profiles...'.loggable,
    );
    final sortedProfiles = await _sortProfiles(profiles);
    App.log(
      '[ProfileListBloc] Sorted ${sortedProfiles.length} profiles'.loggable,
    );

    emit(ProfileListLoaded(profiles: sortedProfiles));
  }

  Future<void> _onUpdate(
    ProfileListUpdateEvent event,
    Emitter<ProfileListState> emit,
  ) async {
    // Sort profiles before emitting the updated state
    final sortedProfiles = await _sortProfiles(event.profiles);
    emit(ProfileListLoaded(profiles: sortedProfiles));
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

    // Sort profiles after adding new ones
    final sortedProfiles = await _sortProfiles(profiles);
    emit(ProfileListLoaded(profiles: sortedProfiles));
  }
}
