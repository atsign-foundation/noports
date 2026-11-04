import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';

part 'profile_cache_state.dart';

class ProfileCacheCubit extends LoggingCubit<ProfileCacheState> {
  final ProfileRepository _repo;
  final ProfileBloc Function(ProfileRepository repo, String uuid) _createBloc;

  /// [createBloc] is injectable so that tests can hand in a bloc whose
  /// sessions they control.
  ProfileCacheCubit(
    this._repo, {
    ProfileBloc Function(ProfileRepository repo, String uuid) createBloc =
        ProfileBloc.new,
  }) : _createBloc = createBloc,
       super(const ProfileCacheState({}));

  ProfileBloc getProfileBloc(String uuid) {
    if (state.profileBlocs.containsKey(uuid)) {
      return state.profileBlocs[uuid]!;
    }

    var bloc = _createBloc(_repo, uuid);
    emit(state.withAdded(uuid, bloc));
    return bloc;
  }

  /// Stops every cached profile and forgets them all, e.g. on sign-out.
  ///
  /// A bloc dropped from the cache is unreachable from the UI, so anything it
  /// is still running - a session, or a keep-alive loop retrying one - would
  /// otherwise carry on behind the user's back with the signed-out atClient.
  void clear() {
    for (final bloc in state.profileBlocs.values) {
      if (!bloc.isClosed) bloc.add(const ProfileStopEvent());
    }
    emit(const ProfileCacheState({}));
  }
}
