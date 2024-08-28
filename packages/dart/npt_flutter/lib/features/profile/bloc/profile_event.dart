part of 'profile_bloc.dart';

sealed class ProfileEvent extends Loggable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileLoadEvent extends ProfileEvent {
  final bool useCache;
  const ProfileLoadEvent({this.useCache = true});

  @override
  String toString() {
    return 'ProfileLoadEvent(useCache: $useCache)';
  }
}

final class ProfileLoadOrCreateEvent extends ProfileEvent {
  const ProfileLoadOrCreateEvent();

  @override
  String toString() {
    return 'ProfileLoadOrCreateEvent';
  }
}

final class ProfileEditEvent extends ProfileEvent {
  final Profile profile;
  const ProfileEditEvent({required this.profile});

  @override
  List<Object?> get props => [profile];

  @override
  String toString() {
    return 'ProfileEditEvent(profile: $profile)';
  }
}

final class ProfileSaveEvent extends ProfileEvent {
  final Profile profile;
  const ProfileSaveEvent({required this.profile});

  @override
  List<Object?> get props => [profile];

  @override
  String toString() {
    return 'ProfileEditEvent(profile: $profile)';
  }
}

final class ProfileStartEvent extends ProfileEvent {
  const ProfileStartEvent();

  @override
  String toString() {
    return 'ProfileStartEvent';
  }
}

final class ProfileStopEvent extends ProfileEvent {
  const ProfileStopEvent();

  @override
  String toString() {
    return 'ProfileStopEvent';
  }
}
