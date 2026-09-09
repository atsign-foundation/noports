part of 'profile_group_bloc.dart';

sealed class ProfileGroupEvent extends Loggable {
  const ProfileGroupEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileGroupLoadEvent extends ProfileGroupEvent {
  const ProfileGroupLoadEvent();

  @override
  String toString() {
    return 'ProfileGroupLoadEvent';
  }
}

final class ProfileGroupCreateEvent extends ProfileGroupEvent {
  final String name;
  final Iterable<String> profileIds;
  const ProfileGroupCreateEvent({
    required this.name,
    this.profileIds = const <String>[],
  });

  @override
  List<Object?> get props => [name, profileIds];

  @override
  String toString() {
    return 'ProfileGroupCreateEvent(name: $name, profileIds: $profileIds)';
  }
}

final class ProfileGroupRenameEvent extends ProfileGroupEvent {
  final String groupId;
  final String name;
  const ProfileGroupRenameEvent({required this.groupId, required this.name});

  @override
  List<Object?> get props => [groupId, name];

  @override
  String toString() {
    return 'ProfileGroupRenameEvent(groupId: $groupId, name: $name)';
  }
}

final class ProfileGroupDeleteEvent extends ProfileGroupEvent {
  final String groupId;
  const ProfileGroupDeleteEvent({required this.groupId});

  @override
  List<Object?> get props => [groupId];

  @override
  String toString() {
    return 'ProfileGroupDeleteEvent(groupId: $groupId)';
  }
}

/// Moves [profileIds] into the group [groupId].
/// A null [groupId] removes the profiles from every group.
final class ProfileGroupMoveProfilesEvent extends ProfileGroupEvent {
  final Iterable<String> profileIds;
  final String? groupId;
  const ProfileGroupMoveProfilesEvent({
    required this.profileIds,
    required this.groupId,
  });

  @override
  List<Object?> get props => [profileIds, groupId];

  @override
  String toString() {
    return 'ProfileGroupMoveProfilesEvent(profileIds: $profileIds, groupId: $groupId)';
  }
}

final class ProfileGroupRemoveProfilesEvent extends ProfileGroupEvent {
  final Iterable<String> profileIds;
  const ProfileGroupRemoveProfilesEvent(this.profileIds);

  @override
  List<Object?> get props => [profileIds];

  @override
  String toString() {
    return 'ProfileGroupRemoveProfilesEvent($profileIds)';
  }
}

final class ProfileGroupSetSortByTypeEvent extends ProfileGroupEvent {
  final bool sortByType;
  const ProfileGroupSetSortByTypeEvent(this.sortByType);

  @override
  List<Object?> get props => [sortByType];

  @override
  String toString() {
    return 'ProfileGroupSetSortByTypeEvent($sortByType)';
  }
}
