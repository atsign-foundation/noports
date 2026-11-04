part of 'profile_cache_cubit.dart';

class ProfileCacheState extends Loggable {
  final Map<String, ProfileBloc> profileBlocs;
  const ProfileCacheState(this.profileBlocs);

  ProfileCacheState withAdded(String uuid, ProfileBloc bloc) {
    return ProfileCacheState({...profileBlocs, uuid: bloc});
  }

  /// This state without [uuid]'s bloc.
  ProfileCacheState withRemoved(String uuid) {
    return ProfileCacheState({...profileBlocs}..remove(uuid));
  }

  @override
  List<Object> get props => [profileBlocs];

  @override
  String toString() {
    return 'ProfileCacheState(uuids:${profileBlocs.keys})';
  }
}
