import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';

part 'profile_cache_state.dart';

class ProfileCacheCubit extends LoggingCubit<ProfileCacheState> {
  final ProfileRepository _repo;
  ProfileCacheCubit(this._repo) : super(const ProfileCacheState({}));

  ProfileBloc getProfileBloc(String uuid) {
    if (state.profileBlocs.containsKey(uuid)) {
      return state.profileBlocs[uuid]!;
    }

    var bloc = ProfileBloc(_repo, uuid);
    emit(state.withAdded(uuid, bloc));
    return bloc;
  }

  void clear() => emit(const ProfileCacheState({}));
}
