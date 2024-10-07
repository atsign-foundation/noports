import 'package:npt_flutter/app.dart';
import 'package:socket_connector/socket_connector.dart';

part 'profiles_running_state.dart';

class ProfilesRunningCubit extends LoggingCubit<ProfilesRunningState> {
  ProfilesRunningCubit() : super(const ProfilesRunningState({}));

  void prepare(String uuid) {
    emit(state.withConnector(uuid, null));
  }

  void cache(String uuid, SocketConnector connector) {
    emit(state.withConnector(uuid, connector));
  }

  void invalidate(String uuid) {
    emit(state.withoutConnector(uuid));
  }

  void stopAllAndClear() {
    state.socketConnectors.forEach((_, socketConnector) {
      socketConnector?.close();
    });
    emit(const ProfilesRunningState({}));
  }
}
