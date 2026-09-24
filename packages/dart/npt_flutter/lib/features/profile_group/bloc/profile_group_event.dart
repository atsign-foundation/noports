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

/// Deletes [groupId]. Its profiles become ungrouped, ordered by
/// [visibleUngrouped] when given.
final class ProfileGroupDeleteEvent extends ProfileGroupEvent {
  final String groupId;
  final List<String>? visibleUngrouped;
  const ProfileGroupDeleteEvent({required this.groupId, this.visibleUngrouped});

  @override
  List<Object?> get props => [groupId, visibleUngrouped];

  @override
  String toString() {
    return 'ProfileGroupDeleteEvent(groupId: $groupId)';
  }
}

/// Moves [profileIds] into the group [groupId].
/// A null [groupId] ungroups them instead, ordered by [visibleUngrouped]
/// when given.
final class ProfileGroupMoveProfilesEvent extends ProfileGroupEvent {
  final Iterable<String> profileIds;
  final String? groupId;
  final List<String>? visibleUngrouped;
  const ProfileGroupMoveProfilesEvent({
    required this.profileIds,
    required this.groupId,
    this.visibleUngrouped,
  });

  @override
  List<Object?> get props => [profileIds, groupId, visibleUngrouped];

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

/// Places [profileIds] into folder [groupId] (null means ungrouped) at
/// [sectionOrder], after a drag-and-drop.
final class ProfileGroupPlaceProfilesEvent extends ProfileGroupEvent {
  final List<String> profileIds;
  final String? groupId;
  final List<String> sectionOrder;
  const ProfileGroupPlaceProfilesEvent({
    required this.profileIds,
    required this.groupId,
    required this.sectionOrder,
  });

  @override
  List<Object?> get props => [profileIds, groupId, sectionOrder];

  @override
  String toString() {
    return 'ProfileGroupPlaceProfilesEvent(profileIds: $profileIds, '
        'groupId: $groupId, sectionOrder: $sectionOrder)';
  }
}

/// Reorders folders to follow [groupIds].
final class ProfileGroupReorderFoldersEvent extends ProfileGroupEvent {
  final List<String> groupIds;
  const ProfileGroupReorderFoldersEvent(this.groupIds);

  @override
  List<Object?> get props => [groupIds];

  @override
  String toString() {
    return 'ProfileGroupReorderFoldersEvent($groupIds)';
  }
}
