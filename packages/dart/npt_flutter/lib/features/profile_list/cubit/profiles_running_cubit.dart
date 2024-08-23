import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';
import 'package:socket_connector/socket_connector.dart';

part 'profiles_running_state.dart';

class ProfilesRunningCubit extends LoggingCubit<ProfilesRunningState> {
  ProfilesRunningCubit() : super(const ProfilesRunningState({}));

  void cache(String uuid, SocketConnector connector) {
    emit(state.withConnector(uuid, connector));
    App.navState.currentContext?.read<TrayCubit>().reloadFavorites();
  }

  void invalidate(String uuid) {
    emit(state.withoutConnector(uuid));
    App.navState.currentContext?.read<TrayCubit>().reloadFavorites();
  }
}
