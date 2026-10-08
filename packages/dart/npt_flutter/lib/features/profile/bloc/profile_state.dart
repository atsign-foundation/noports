part of 'profile_bloc.dart';

sealed class ProfileState extends Loggable {
  final String uuid;
  const ProfileState(this.uuid);

  @override
  List<Object?> get props => [uuid];
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial(super.uuid);

  @override
  String toString() {
    return 'ProfileInitial($uuid)';
  }
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading(super.uuid);

  @override
  String toString() {
    return 'ProfileLoading($uuid)';
  }
}

final class ProfileFailedLoad extends ProfileState {
  const ProfileFailedLoad(super.uuid);

  @override
  String toString() {
    return 'ProfileFailedLoad($uuid)';
  }
}

sealed class ProfileLoadedState extends ProfileState {
  final Profile profile;
  const ProfileLoadedState(super.uuid, {required this.profile});

  @override
  List<Object?> get props => [uuid, profile];
}

final class ProfileLoaded extends ProfileLoadedState {
  const ProfileLoaded(super.uuid, {required super.profile});

  @override
  String toString() {
    return 'ProfileLoaded($uuid, profile: $profile)';
  }
}

final class ProfileFailedSave extends ProfileLoadedState {
  const ProfileFailedSave(super.uuid, {required super.profile});

  @override
  String toString() {
    return 'ProfileFailedSave($uuid, profile: $profile)';
  }
}

final class ProfileStarting extends ProfileLoadedState {
  final String? status;
  const ProfileStarting(super.uuid, {required super.profile, this.status});

  @override
  String toString() {
    return 'ProfileStarting($uuid, status: $status, profile: $profile)';
  }

  @override
  List<Object?> get props => [uuid, profile, status];
}

final class ProfileStarted extends ProfileLoadedState {
  const ProfileStarted(super.uuid, {required super.profile});

  @override
  String toString() {
    return 'ProfileStarted($uuid, profile: $profile)';
  }
}

final class ProfileStopping extends ProfileLoadedState {
  const ProfileStopping(super.uuid, {required super.profile});
  @override
  String toString() {
    return 'ProfileStopping($uuid, profile: $profile)';
  }
}

final class ProfileFailedStart extends ProfileLoadedState {
  final String? reason;
  const ProfileFailedStart(super.uuid, {required super.profile, this.reason});
  @override
  String toString() {
    return 'ProfileFailedStart($uuid, reason: $reason, profile: $profile)';
  }
}
