import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

part 'profile_list_filter_state.dart';

/// Search and sort applied to the connections list. Not logged: it changes on
/// every keystroke.
class ProfileListFilterCubit extends Cubit<ProfileListFilterState> {
  final ProfileCacheCubit _cache;
  final Map<String, StreamSubscription<ProfileState>> _followed =
      <String, StreamSubscription<ProfileState>>{};
  List<String> _uuids = const <String>[];

  ProfileListFilterCubit(this._cache) : super(const ProfileListFilterState());

  void search(String query) {
    emit(state.copyWith(query: query));
    _follow();
  }

  void sort(ProfileSortMode sortMode) {
    emit(state.copyWith(sortMode: sortMode));
    _follow();
  }

  void setFavoritesFirst(bool favoritesFirst) =>
      emit(state.copyWith(favoritesFirst: favoritesFirst));

  void useSettings(Settings settings) {
    emit(
      state.copyWith(
        sortMode: settings.sortMode,
        favoritesFirst: settings.favoritesFirst,
      ),
    );
    _follow();
  }

  void setFolders(List<ProfileGroup> folders) =>
      emit(state.copyWith(folders: folders));

  void setProfiles(Iterable<String> uuids) {
    _uuids = uuids.toList();
    _follow();
  }

  /// Loads and follows the listed profiles while searching or sorting by name
  /// needs their details. Rows only load the profiles they show.
  void _follow() {
    final Set<String> wanted = state.needsProfiles
        ? _uuids.toSet()
        : const <String>{};
    for (final String uuid in _followed.keys.toList()) {
      if (!wanted.contains(uuid)) _followed.remove(uuid)?.cancel();
    }
    final Map<String, Profile> profiles = <String, Profile>{
      for (final MapEntry<String, Profile> entry in state.profiles.entries)
        if (wanted.contains(entry.key)) entry.key: entry.value,
    };
    final Set<String> failed = state.failed.intersection(wanted);
    for (final String uuid in wanted) {
      if (_followed.containsKey(uuid)) continue;
      final ProfileBloc bloc = _cache.getProfileBloc(uuid);
      if (bloc.state is ProfileInitial) bloc.add(const ProfileLoadEvent());
      final ProfileState current = bloc.state;
      if (current is ProfileLoadedState) profiles[uuid] = current.profile;
      if (current is ProfileFailedLoad) failed.add(uuid);
      _followed[uuid] = bloc.stream.listen((ProfileState next) {
        if (next is ProfileFailedLoad) {
          emit(state.copyWith(failed: <String>{...state.failed, uuid}));
        }
        if (next is! ProfileLoadedState) return;
        if (state.profiles[uuid] == next.profile) return;
        emit(
          state.copyWith(
            profiles: <String, Profile>{...state.profiles, uuid: next.profile},
            failed: state.failed.difference(<String>{uuid}),
          ),
        );
      });
    }
    emit(state.copyWith(profiles: profiles, failed: failed));
  }

  @override
  Future<void> close() {
    for (final StreamSubscription<ProfileState> s in _followed.values) {
      s.cancel();
    }
    _followed.clear();
    return super.close();
  }
}
