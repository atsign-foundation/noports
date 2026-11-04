part of 'profile_folder_bloc.dart';

sealed class ProfileFolderEvent extends Loggable {
  const ProfileFolderEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileFolderLoadEvent extends ProfileFolderEvent {
  const ProfileFolderLoadEvent();

  @override
  String toString() {
    return 'ProfileFolderLoadEvent';
  }
}

/// Re-reads the folders after a sync round, without going through a loading
/// state. [caughtUp] is true once nothing is left to pull or push.
final class ProfileFolderRefreshEvent extends ProfileFolderEvent {
  final bool caughtUp;
  const ProfileFolderRefreshEvent({this.caughtUp = false});

  @override
  List<Object?> get props => [caughtUp];

  @override
  String toString() {
    return 'ProfileFolderRefreshEvent(caughtUp: $caughtUp)';
  }
}

/// Ignored when a folder with [uuid] already exists.
final class ProfileFolderCreateEvent extends ProfileFolderEvent {
  final String uuid;
  final String name;
  final Iterable<String> profileIds;
  const ProfileFolderCreateEvent({
    required this.uuid,
    required this.name,
    this.profileIds = const <String>[],
  });

  @override
  List<Object?> get props => [uuid, name, profileIds];

  @override
  String toString() {
    return 'ProfileFolderCreateEvent(uuid: $uuid, name: $name, '
        'profileIds: $profileIds)';
  }
}

final class ProfileFolderRenameEvent extends ProfileFolderEvent {
  final String folderId;
  final String name;
  const ProfileFolderRenameEvent({required this.folderId, required this.name});

  @override
  List<Object?> get props => [folderId, name];

  @override
  String toString() {
    return 'ProfileFolderRenameEvent(folderId: $folderId, name: $name)';
  }
}

/// Deletes [folderId]. Its profiles become unfiled, ordered by
/// [visibleUnfiled] when given.
final class ProfileFolderDeleteEvent extends ProfileFolderEvent {
  final String folderId;
  final List<String>? visibleUnfiled;
  const ProfileFolderDeleteEvent({required this.folderId, this.visibleUnfiled});

  @override
  List<Object?> get props => [folderId, visibleUnfiled];

  @override
  String toString() {
    return 'ProfileFolderDeleteEvent(folderId: $folderId)';
  }
}

/// Moves [profileIds] into the folder [folderId].
/// A null [folderId] takes them out of every folder instead, ordered by [visibleUnfiled]
/// when given.
final class ProfileFolderMoveProfilesEvent extends ProfileFolderEvent {
  final Iterable<String> profileIds;
  final String? folderId;
  final List<String>? visibleUnfiled;
  const ProfileFolderMoveProfilesEvent({
    required this.profileIds,
    required this.folderId,
    this.visibleUnfiled,
  });

  @override
  List<Object?> get props => [profileIds, folderId, visibleUnfiled];

  @override
  String toString() {
    return 'ProfileFolderMoveProfilesEvent(profileIds: $profileIds, folderId: $folderId)';
  }
}

final class ProfileFolderRemoveProfilesEvent extends ProfileFolderEvent {
  final Iterable<String> profileIds;
  const ProfileFolderRemoveProfilesEvent(this.profileIds);

  @override
  List<Object?> get props => [profileIds];

  @override
  String toString() {
    return 'ProfileFolderRemoveProfilesEvent($profileIds)';
  }
}

/// Places [profileIds] into [folderId] (null means unfiled) at [sectionOrder].
final class ProfileFolderPlaceProfilesEvent extends ProfileFolderEvent {
  final List<String> profileIds;
  final String? folderId;
  final List<String> sectionOrder;
  const ProfileFolderPlaceProfilesEvent({
    required this.profileIds,
    required this.folderId,
    required this.sectionOrder,
  });

  @override
  List<Object?> get props => [profileIds, folderId, sectionOrder];

  @override
  String toString() {
    return 'ProfileFolderPlaceProfilesEvent(profileIds: $profileIds, '
        'folderId: $folderId, sectionOrder: $sectionOrder)';
  }
}

final class ProfileFolderReorderEvent extends ProfileFolderEvent {
  final List<String> folderIds;
  const ProfileFolderReorderEvent(this.folderIds);

  @override
  List<Object?> get props => [folderIds];

  @override
  String toString() {
    return 'ProfileFolderReorderEvent($folderIds)';
  }
}

final class ProfileFolderSetFavoriteEvent extends ProfileFolderEvent {
  final String folderId;
  final bool favorite;
  const ProfileFolderSetFavoriteEvent({
    required this.folderId,
    required this.favorite,
  });

  @override
  List<Object?> get props => [folderId, favorite];

  @override
  String toString() {
    return 'ProfileFolderSetFavoriteEvent(folderId: $folderId, '
        'favorite: $favorite)';
  }
}

/// A null [folderId] is the "No folder" section.
final class ProfileFolderSetCollapsedEvent extends ProfileFolderEvent {
  final String? folderId;
  final bool collapsed;
  const ProfileFolderSetCollapsedEvent({
    required this.folderId,
    required this.collapsed,
  });

  @override
  List<Object?> get props => [folderId, collapsed];

  @override
  String toString() {
    return 'ProfileFolderSetCollapsedEvent(folderId: $folderId, '
        'collapsed: $collapsed)';
  }
}

final class ProfileFolderSetSkippedByStartAllEvent extends ProfileFolderEvent {
  final String folderId;
  final List<String> skipped;
  const ProfileFolderSetSkippedByStartAllEvent({
    required this.folderId,
    required this.skipped,
  });

  @override
  List<Object?> get props => [folderId, skipped];

  @override
  String toString() {
    return 'ProfileFolderSetSkippedByStartAllEvent(folderId: $folderId, '
        'skipped: $skipped)';
  }
}
