part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileLoadEvent extends ProfileEvent {
  const ProfileLoadEvent();
}

final class ProfileEditEvent extends ProfileEvent {
  final Profile profile;
  final bool save;

  const ProfileEditEvent({required this.profile, required this.save});

  @override
  List<Object?> get props => [profile, save];
}

final class ProfileStartEvent extends ProfileEvent {
  const ProfileStartEvent();
}

final class ProfileStopEvent extends ProfileEvent {
  const ProfileStopEvent();
}
