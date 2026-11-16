part of 'profile_start_queue_cubit.dart';

/// The connections waiting to start, each until its start is sent.
final class ProfileStartQueueState extends Loggable {
  final List<String> waiting;
  const ProfileStartQueueState(this.waiting);

  bool isWaiting(String uuid) => waiting.contains(uuid);

  @override
  List<Object?> get props => [waiting];

  @override
  String toString() {
    return 'ProfileStartQueueState($waiting)';
  }
}
