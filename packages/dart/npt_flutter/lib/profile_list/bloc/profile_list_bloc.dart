import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/profile_list/profile_list.dart';

part 'profile_list_event.dart';
part 'profile_list_state.dart';

class ProfileListBloc extends Bloc<ProfileListEvent, ProfileListState> {
  final ProfileListRepository _repo;
  ProfileListBloc(this._repo) : super(const ProfileListInitial()) {
    on<ProfileListLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(
      ProfileListLoadEvent event, Emitter<ProfileListState> emit) async {
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
}
