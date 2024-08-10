part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  final String uuid;
  const ProfileState(this.uuid);

  @override
  List<Object?> get props => [uuid];
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial(super.uuid);
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading(super.uuid);
}

final class ProfileFailedLoad extends ProfileState {
  const ProfileFailedLoad(super.uuid);
}

sealed class ProfileLoadedState extends ProfileState {
  final Profile profile;
  const ProfileLoadedState(super.uuid, {required this.profile});

  @override
  List<Object?> get props => [uuid, profile];
}

final class ProfileLoaded extends ProfileLoadedState {
  const ProfileLoaded(super.uuid, {required super.profile});
}

final class ProfileFailedSave extends ProfileLoadedState {
  const ProfileFailedSave(super.uuid, {required super.profile});
}

final class ProfileStarting extends ProfileLoadedState {
  final String? status;
  const ProfileStarting(super.uuid, {required super.profile, this.status});
}

final class ProfileStarted extends ProfileLoadedState {
  const ProfileStarted(super.uuid, {required super.profile});
}

final class ProfileStopping extends ProfileLoadedState {
  const ProfileStopping(super.uuid, {required super.profile});
}

final class ProfileFailedStart extends ProfileLoadedState {
  final String? reason;
  const ProfileFailedStart(super.uuid, {required super.profile, this.reason});
}
