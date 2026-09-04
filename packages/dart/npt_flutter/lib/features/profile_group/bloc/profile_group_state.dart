part of 'profile_group_bloc.dart';

sealed class ProfileGroupState extends Loggable {
  const ProfileGroupState();

  @override
  List<Object?> get props => [];
}

final class ProfileGroupsInitial extends ProfileGroupState {
  const ProfileGroupsInitial();

  @override
  String toString() {
    return 'ProfileGroupsInitial';
  }
}

final class ProfileGroupsLoading extends ProfileGroupState {
  const ProfileGroupsLoading();

  @override
  String toString() {
    return 'ProfileGroupsLoading';
  }
}

final class ProfileGroupsFailedLoad extends ProfileGroupState {
  const ProfileGroupsFailedLoad();

  @override
  String toString() {
    return 'ProfileGroupsFailedLoad';
  }
}

final class ProfileGroupsLoaded extends ProfileGroupState {
  final ProfileGroupData data;
  const ProfileGroupsLoaded(this.data);

  List<ProfileGroup> get groups => data.groups;
  bool get sortByType => data.sortByType;

  @override
  List<Object?> get props => [data];

  @override
  String toString() {
    return 'ProfileGroupsLoaded($data)';
  }
}
