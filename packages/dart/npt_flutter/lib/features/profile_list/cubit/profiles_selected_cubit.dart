import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profiles_selected_state.dart';

class ProfilesSelectedCubit extends LoggingCubit<ProfilesSelectedState> {
  ProfilesSelectedCubit() : super(const ProfilesSelectedState({}));

  void select(String uuid) => emit(state.withAdded({uuid}));
  void deselect(String uuid) => emit(state.withRemoved({uuid}));
  void deselectAll() => emit(const ProfilesSelectedState({}));

  void selectAll() {
    var bloc = App.navState.currentContext?.read<ProfileListBloc>();
    if (bloc != null && bloc.state is ProfileListLoaded) {
      emit(ProfilesSelectedState(
        (bloc.state as ProfileListLoaded).profiles.toSet(),
      ));
    }
  }
}
