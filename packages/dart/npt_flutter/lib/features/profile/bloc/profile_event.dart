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
  final bool save;
  final bool addToProfilesList;
  final bool popNavAfterAddToProfilesList;
  const ProfileEditEvent({
    required this.profile,
    required this.save,
    this.addToProfilesList = false,
    this.popNavAfterAddToProfilesList = false,
  });

  @override
  List<Object?> get props =>
      [profile, save, addToProfilesList, popNavAfterAddToProfilesList];

  @override
  String toString() {
    return 'ProfileEditEvent(save:$save, profile: $profile, '
        'add: $addToProfilesList, popNav:$popNavAfterAddToProfilesList)';
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
