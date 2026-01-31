part of 'profile_list_bloc.dart';

sealed class ProfileListEvent extends Loggable {
  const ProfileListEvent();

  @override
  List<Object> get props => [];
}

final class ProfileListLoadEvent extends ProfileListEvent {
  const ProfileListLoadEvent();

  @override
  String toString() {
    return 'ProfileListLoadEvent';
  }
}

final class ProfileListUpdateEvent extends ProfileListEvent {
  final Iterable<String> profiles;
  const ProfileListUpdateEvent(this.profiles);

  @override
  List<Object> get props => [profiles];

  @override
  String toString() {
    return 'ProfileListUpdateEvent($profiles)';
  }
}

final class ProfileListDeleteEvent extends ProfileListEvent {
  final Iterable<String> toDelete;
  const ProfileListDeleteEvent({required this.toDelete});

  @override
  List<Object> get props => [toDelete];

  @override
  String toString() {
    return 'ProfileListDeleteEvent(toDelete: $toDelete)';
  }
}

// asynchronously add an entire list of profiles at once
// useful for importing which is dependant on a ton of async tasks
final class ProfileListAddEvent extends ProfileListEvent {
  final Iterable<Profile> toAdd;
  const ProfileListAddEvent(this.toAdd);

  @override
  List<Object> get props => [toAdd];

  @override
  String toString() {
    return 'ProfileListAddEvent(toAdd: $toAdd)';
  }
}
