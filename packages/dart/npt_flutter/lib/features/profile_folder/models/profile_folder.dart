import 'package:flutter/foundation.dart';
import 'package:npt_flutter/app.dart';

Map<String, dynamic> _unknownFields(
  Map<String, dynamic> json,
  Set<String> known,
) => <String, dynamic>{
  for (final MapEntry<String, dynamic> e in json.entries)
    if (!known.contains(e.key)) e.key: e.value,
};

final class ProfileFolder extends Loggable {
  final String uuid;
  final String name;
  final List<String> profileIds;

  final bool favorite;

  final bool collapsed;

  /// Stored as exclusions, so a connection added later starts by default.
  final List<String> skippedByStartAll;

  /// Stored fields this version doesn't know, written back unchanged.
  final Map<String, dynamic> unknown;

  const ProfileFolder({
    required this.uuid,
    required this.name,
    this.profileIds = const <String>[],
    this.favorite = false,
    this.collapsed = false,
    this.skippedByStartAll = const <String>[],
    this.unknown = const <String, dynamic>{},
  });

  ProfileFolder copyWith({
    String? name,
    List<String>? profileIds,
    bool? favorite,
    bool? collapsed,
    List<String>? skippedByStartAll,
  }) {
    return ProfileFolder(
      uuid: uuid,
      name: name ?? this.name,
      profileIds: profileIds ?? this.profileIds,
      favorite: favorite ?? this.favorite,
      collapsed: collapsed ?? this.collapsed,
      skippedByStartAll: skippedByStartAll ?? this.skippedByStartAll,
      unknown: unknown,
    );
  }

  bool containsProfile(String profileId) => profileIds.contains(profileId);

  bool startsWithAll(String profileId) =>
      !skippedByStartAll.contains(profileId);

  ProfileFolder withoutProfiles(Iterable<String> toRemove) {
    final Set<String> removeSet = toRemove.toSet();
    return copyWith(
      profileIds: profileIds
          .where((String id) => !removeSet.contains(id))
          .toList(),
      skippedByStartAll: skippedByStartAll
          .where((String id) => !removeSet.contains(id))
          .toList(),
    );
  }

  ProfileFolder withProfiles(Iterable<String> toAdd) {
    final List<String> merged = List<String>.from(profileIds);
    for (final String id in toAdd) {
      if (!merged.contains(id)) merged.add(id);
    }
    return copyWith(profileIds: merged);
  }

  static const String _uuidKey = 'uuid';
  static const String _nameKey = 'name';
  static const String _profileIdsKey = 'profileIds';
  static const String _favoriteKey = 'favorite';
  static const String _collapsedKey = 'collapsed';
  static const String _skippedByStartAllKey = 'skippedByStartAll';
  static const Set<String> _keys = <String>{
    _uuidKey,
    _nameKey,
    _profileIdsKey,
    _favoriteKey,
    _collapsedKey,
    _skippedByStartAllKey,
  };

  factory ProfileFolder.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawIds = json[_profileIdsKey] is List
        ? json[_profileIdsKey] as List<dynamic>
        : const <dynamic>[];
    final List<dynamic> rawSkipped = json[_skippedByStartAllKey] is List
        ? json[_skippedByStartAllKey] as List<dynamic>
        : const <dynamic>[];
    final dynamic uuid = json[_uuidKey];
    final dynamic name = json[_nameKey];
    final List<String> profileIds = rawIds.whereType<String>().toList();
    return ProfileFolder(
      uuid: uuid is String ? uuid : '',
      name: name is String ? name : '',
      profileIds: profileIds,
      favorite: json[_favoriteKey] == true,
      collapsed: json[_collapsedKey] == true,
      skippedByStartAll: rawSkipped
          .whereType<String>()
          .where(profileIds.contains)
          .toSet()
          .toList(),
      unknown: _unknownFields(json, _keys),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...unknown,
    _uuidKey: uuid,
    _nameKey: name,
    _profileIdsKey: profileIds,
    if (favorite) _favoriteKey: true,
    if (collapsed) _collapsedKey: true,
    if (skippedByStartAll.isNotEmpty) _skippedByStartAllKey: skippedByStartAll,
  };

  @override
  List<Object?> get props => [
    uuid,
    name,
    profileIds,
    favorite,
    collapsed,
    skippedByStartAll,
    unknown,
  ];

  @override
  String toString() {
    return 'ProfileFolder(uuid: $uuid, name: $name, profileIds: $profileIds, '
        'favorite: $favorite, collapsed: $collapsed, '
        'skippedByStartAll: $skippedByStartAll)';
  }
}

/// An id appears in at most one place across every folder and [unfiled].
final class ProfileFolderData extends Loggable {
  final List<ProfileFolder> folders;
  final List<String> unfiled;

  final bool unfiledCollapsed;

  /// Stored fields this version doesn't know, written back unchanged.
  final Map<String, dynamic> unknown;

  const ProfileFolderData({
    this.folders = const <ProfileFolder>[],
    this.unfiled = const <String>[],
    this.unfiledCollapsed = false,
    this.unknown = const <String, dynamic>{},
  });

  ProfileFolderData copyWith({
    List<ProfileFolder>? folders,
    List<String>? unfiled,
    bool? unfiledCollapsed,
  }) {
    return ProfileFolderData(
      folders: folders ?? this.folders,
      unfiled: unfiled ?? this.unfiled,
      unfiledCollapsed: unfiledCollapsed ?? this.unfiledCollapsed,
      unknown: unknown,
    );
  }

  ProfileFolder? folderForProfile(String profileId) {
    for (final ProfileFolder folder in folders) {
      if (folder.containsProfile(profileId)) return folder;
    }
    return null;
  }

  ProfileFolderData withCollapsed(String? folderId, bool collapsed) {
    if (folderId == null) return copyWith(unfiledCollapsed: collapsed);
    return copyWith(
      folders: folders
          .map(
            (ProfileFolder f) =>
                f.uuid == folderId ? f.copyWith(collapsed: collapsed) : f,
          )
          .toList(),
    );
  }

  /// Without folders there are no sections to collapse.
  bool isCollapsed(String profileId) =>
      folders.isNotEmpty &&
      (folderForProfile(profileId)?.collapsed ?? unfiledCollapsed);

  ProfileFolder? folderById(String folderId) {
    for (final ProfileFolder folder in folders) {
      if (folder.uuid == folderId) return folder;
    }
    return null;
  }

  /// Stored order first, then the other unclaimed loaded ids in load order.
  List<String> resolveUnfiled(Iterable<String> loaded) {
    final List<String> loadedList = loaded.toList();
    final Set<String> loadedSet = loadedList.toSet();
    final Set<String> claimed = <String>{
      for (final ProfileFolder folder in folders) ...folder.profileIds,
    };
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (final String id in unfiled) {
      if (loadedSet.contains(id) && !claimed.contains(id) && seen.add(id)) {
        result.add(id);
      }
    }
    for (final String id in loadedList) {
      if (!claimed.contains(id) && seen.add(id)) result.add(id);
    }
    return result;
  }

  ProfileFolderData withoutProfilesEverywhere(Iterable<String> ids) {
    final Set<String> remove = ids.toSet();
    return copyWith(
      folders: folders
          .map((ProfileFolder f) => f.withoutProfiles(remove))
          .toList(),
      unfiled: unfiled.where((String id) => !remove.contains(id)).toList(),
    );
  }

  /// Puts [ids] after [visibleUnfiled], or with the unpositioned ones.
  ProfileFolderData withProfilesUnfiled(
    Iterable<String> ids, {
    List<String>? visibleUnfiled,
  }) {
    final List<String> movedOut = <String>[];
    for (final String id in ids) {
      if (folderForProfile(id) != null && !movedOut.contains(id)) {
        movedOut.add(id);
      }
    }
    if (movedOut.isEmpty) return this;
    final Set<String> movedSet = movedOut.toSet();
    final List<ProfileFolder> folders = this.folders
        .map((ProfileFolder f) => f.withoutProfiles(movedSet))
        .toList();
    if (visibleUnfiled == null) return copyWith(folders: folders);

    final List<String> base = mergeVisibleOrder(
      unfiled,
      visibleUnfiled
          .where(
            (String id) =>
                !movedSet.contains(id) && folderForProfile(id) == null,
          )
          .toList(),
    );
    return copyWith(
      folders: folders,
      unfiled: <String>[
        ...base.where((String id) => !movedSet.contains(id)),
        ...movedOut,
      ],
    );
  }

  /// Ids a stale view shows in another folder are skipped.
  ProfileFolderData placeProfiles({
    required List<String> profileIds,
    required String? folderId,
    required List<String> sectionOrder,
  }) {
    final ProfileFolder? target = folderId == null
        ? null
        : folderById(folderId);
    if (folderId != null && target == null) return this;
    final Set<String> moved = profileIds.toSet();
    final List<String> targetStored = target?.profileIds ?? unfiled;
    final Set<String> targetSet = targetStored.toSet();
    final Set<String> claimedElsewhere = <String>{
      for (final ProfileFolder f in folders)
        if (f.uuid != folderId) ...f.profileIds,
    };

    final List<String> order = <String>[];
    for (final String id in sectionOrder) {
      if (order.contains(id)) continue;
      final bool allowed =
          moved.contains(id) ||
          targetSet.contains(id) ||
          (folderId == null && !claimedElsewhere.contains(id));
      if (allowed) order.add(id);
    }
    for (final String id in profileIds) {
      if (!order.contains(id)) order.add(id);
    }

    final List<String> newTarget = mergeVisibleOrder(
      targetStored.where((String id) => !moved.contains(id)).toList(),
      order,
    );

    final ProfileFolderData stripped = withoutProfilesEverywhere(moved);
    if (folderId == null) return stripped.copyWith(unfiled: newTarget);
    return stripped.copyWith(
      folders: stripped.folders
          .map(
            (ProfileFolder f) => f.uuid == folderId
                ? f.copyWith(
                    profileIds: newTarget,
                    skippedByStartAll: target!.skippedByStartAll
                        .where(newTarget.contains)
                        .toList(),
                  )
                : f,
          )
          .toList(),
    );
  }

  ProfileFolderData withFoldersOrdered(List<String> folderIds) {
    final List<ProfileFolder> ordered = <ProfileFolder>[];
    final Set<String> placed = <String>{};
    for (final String id in folderIds) {
      final ProfileFolder? folder = folderById(id);
      if (folder != null && placed.add(id)) ordered.add(folder);
    }
    for (final ProfileFolder folder in folders) {
      if (placed.add(folder.uuid)) ordered.add(folder);
    }
    return copyWith(folders: ordered);
  }

  /// Ids hidden from [visible] stay just before the next visible id after them.
  static List<String> mergeVisibleOrder(
    List<String> stored,
    List<String> visible,
  ) {
    final Set<String> visibleSet = visible.toSet();
    final Map<String, List<String>> hiddenBefore = <String, List<String>>{};
    List<String> pending = <String>[];
    for (final String id in stored) {
      if (visibleSet.contains(id)) {
        if (pending.isNotEmpty) {
          hiddenBefore[id] = pending;
          pending = <String>[];
        }
      } else {
        pending.add(id);
      }
    }
    final List<String> result = <String>[];
    for (final String id in visible) {
      result.addAll(hiddenBefore[id] ?? const <String>[]);
      result.add(id);
    }
    result.addAll(pending);
    return result;
  }

  /// Places [moved] in [manual] from the screen order [released]: next to the
  /// ids they [tie] with, and only when their order among those changed.
  static List<String> placeInManualOrder({
    required List<String> manual,
    required List<String> released,
    required List<String> moved,
    required bool Function(String a, String b) tie,
  }) {
    final Set<String> shown = released.toSet();
    final List<List<String>> sets = <List<String>>[];
    for (final String id in moved) {
      final List<String>? same = sets
          .where((List<String> s) => tie(s.first, id))
          .firstOrNull;
      same == null ? sets.add(<String>[id]) : same.add(id);
    }
    List<String> result = List<String>.of(manual);
    for (final List<String> set in sets) {
      bool peer(String id) => tie(set.first, id);
      final List<String> onScreen = released.where(peer).toList();
      final List<String> before = result
          .where((String id) => shown.contains(id) && peer(id))
          .toList();
      if (listEquals(before, onScreen)) continue;
      final Set<String> setIds = set.toSet();
      final int first = onScreen.indexWhere(setIds.contains);
      final int last = onScreen.lastIndexWhere(setIds.contains);
      final String? next = first < 0
          ? null
          : onScreen.skip(last + 1).firstOrNull;
      final String? previous = first > 0 ? onScreen[first - 1] : null;
      result = result.where((String id) => !setIds.contains(id)).toList();
      int at = result.length;
      if (next != null && result.contains(next)) {
        at = result.indexOf(next);
      } else if (previous != null && result.contains(previous)) {
        at = result.indexOf(previous) + 1;
      }
      result.insertAll(at, set);
    }
    return result;
  }

  static const String _foldersKey = 'folders';
  static const String _unfiledKey = 'unfiled';
  static const String _unfiledCollapsedKey = 'unfiledCollapsed';
  static const Set<String> _keys = <String>{
    _foldersKey,
    _unfiledKey,
    _unfiledCollapsedKey,
  };

  factory ProfileFolderData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawFolders = json[_foldersKey] is List
        ? json[_foldersKey] as List<dynamic>
        : const <dynamic>[];
    final List<dynamic> rawUnfiled = json[_unfiledKey] is List
        ? json[_unfiledKey] as List<dynamic>
        : const <dynamic>[];

    final Map<String, int> folderIndex = <String, int>{};
    final Set<String> seenIds = <String>{};
    final List<ProfileFolder> folders = <ProfileFolder>[];
    for (final Map raw in rawFolders.whereType<Map>()) {
      final ProfileFolder folder = ProfileFolder.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (folder.uuid.isEmpty) continue;
      final List<String> ids = folder.profileIds.where(seenIds.add).toList();
      final int? first = folderIndex[folder.uuid];
      if (first != null) {
        folders[first] = folders[first].withProfiles(ids);
        continue;
      }
      folderIndex[folder.uuid] = folders.length;
      folders.add(
        folder.copyWith(
          profileIds: ids,
          skippedByStartAll: folder.skippedByStartAll
              .where(ids.contains)
              .toList(),
        ),
      );
    }
    return ProfileFolderData(
      folders: folders,
      unfiled: rawUnfiled.whereType<String>().where(seenIds.add).toList(),
      unfiledCollapsed: json[_unfiledCollapsedKey] == true,
      unknown: _unknownFields(json, _keys),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...unknown,
    _foldersKey: folders
        .map((ProfileFolder folder) => folder.toJson())
        .toList(),
    _unfiledKey: unfiled,
    if (unfiledCollapsed) _unfiledCollapsedKey: true,
  };

  @override
  List<Object?> get props => [folders, unfiled, unfiledCollapsed, unknown];

  @override
  String toString() {
    return 'ProfileFolderData(folders: $folders, unfiled: $unfiled, '
        'unfiledCollapsed: $unfiledCollapsed)';
  }
}
