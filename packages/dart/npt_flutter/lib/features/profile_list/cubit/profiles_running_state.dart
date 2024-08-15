part of 'profiles_running_cubit.dart';

final class ProfilesRunningState extends Loggable {
  final Map<String, SocketConnector> socketConnectors;
  const ProfilesRunningState(this.socketConnectors);

  ProfilesRunningState withConnector(String uuid, SocketConnector connector) {
    return ProfilesRunningState(
      Map.fromEntries([...socketConnectors.entries, MapEntry(uuid, connector)]),
    );
  }

  ProfilesRunningState withoutConnector(String uuid) {
    if (!socketConnectors.containsKey(uuid)) {
      return this;
    }

    socketConnectors[uuid]?.close();
    return ProfilesRunningState(
      Map.fromEntries(socketConnectors.entries.where((e) => e.key != uuid)),
    );
  }

  @override
  List<Object?> get props => [socketConnectors];

  @override
  String toString() {
    return 'ProfilesRunningState($socketConnectors)';
  }
}
