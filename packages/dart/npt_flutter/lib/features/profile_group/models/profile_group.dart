import 'package:npt_flutter/app.dart';

final class ProfileGroup extends Loggable {
  final String uuid;
  final String name;
  final List<String> profileIds;

  const ProfileGroup({
    required this.uuid,
    required this.name,
    this.profileIds = const <String>[],
  });

  ProfileGroup copyWith({String? name, List<String>? profileIds}) {
    return ProfileGroup(
      uuid: uuid,
      name: name ?? this.name,
      profileIds: profileIds ?? this.profileIds,
    );
  }

  bool containsProfile(String profileId) => profileIds.contains(profileId);

  ProfileGroup withoutProfiles(Iterable<String> toRemove) {
    final Set<String> removeSet = toRemove.toSet();
    return copyWith(
      profileIds: profileIds
          .where((String id) => !removeSet.contains(id))
          .toList(),
    );
  }

  ProfileGroup withProfiles(Iterable<String> toAdd) {
    final List<String> merged = List<String>.from(profileIds);
    for (final String id in toAdd) {
      if (!merged.contains(id)) merged.add(id);
    }
    return copyWith(profileIds: merged);
  }

  static const String _uuidKey = 'uuid';
  static const String _nameKey = 'name';
  static const String _profileIdsKey = 'profileIds';

  factory ProfileGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawIds = json[_profileIdsKey] is List
        ? json[_profileIdsKey] as List<dynamic>
        : const <dynamic>[];
    return ProfileGroup(
      uuid: json[_uuidKey] as String? ?? '',
      name: json[_nameKey] as String? ?? '',
      profileIds: rawIds.whereType<String>().toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    _uuidKey: uuid,
    _nameKey: name,
    _profileIdsKey: profileIds,
  };

  @override
  List<Object?> get props => [uuid, name, profileIds];

  @override
  String toString() {
    return 'ProfileGroup(uuid: $uuid, name: $name, profileIds: $profileIds)';
  }
}

/// An id appears in at most one place across every group and [ungrouped].
final class ProfileGroupData extends Loggable {
  final List<ProfileGroup> groups;
  final List<String> ungrouped;

  const ProfileGroupData({
    this.groups = const <ProfileGroup>[],
    this.ungrouped = const <String>[],
  });

  ProfileGroupData copyWith({
    List<ProfileGroup>? groups,
    List<String>? ungrouped,
  }) {
    return ProfileGroupData(
      groups: groups ?? this.groups,
      ungrouped: ungrouped ?? this.ungrouped,
    );
  }

  ProfileGroup? groupForProfile(String profileId) {
    for (final ProfileGroup group in groups) {
      if (group.containsProfile(profileId)) return group;
    }
    return null;
  }

  ProfileGroup? groupById(String groupId) {
    for (final ProfileGroup group in groups) {
      if (group.uuid == groupId) return group;
    }
    return null;
  }

  /// Stored order first, then the other unclaimed loaded ids in load order.
  List<String> resolveUngrouped(Iterable<String> loaded) {
    final List<String> loadedList = loaded.toList();
    final Set<String> loadedSet = loadedList.toSet();
    final Set<String> claimed = <String>{
      for (final ProfileGroup group in groups) ...group.profileIds,
    };
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};
    for (final String id in ungrouped) {
      if (loadedSet.contains(id) && !claimed.contains(id) && seen.add(id)) {
        result.add(id);
      }
    }
    for (final String id in loadedList) {
      if (!claimed.contains(id) && seen.add(id)) result.add(id);
    }
    return result;
  }

  ProfileGroupData withoutProfilesEverywhere(Iterable<String> ids) {
    final Set<String> remove = ids.toSet();
    return copyWith(
      groups: groups
          .map((ProfileGroup g) => g.withoutProfiles(remove))
          .toList(),
      ungrouped: ungrouped.where((String id) => !remove.contains(id)).toList(),
    );
  }

  /// Takes [ids] out of their folders and puts them after everything in
  /// [visibleUngrouped]; without it they join the unpositioned connections.
  ProfileGroupData withProfilesUngrouped(
    Iterable<String> ids, {
    List<String>? visibleUngrouped,
  }) {
    final List<String> movedOut = <String>[];
    for (final String id in ids) {
      if (groupForProfile(id) != null && !movedOut.contains(id)) {
        movedOut.add(id);
      }
    }
    if (movedOut.isEmpty) return this;
    final Set<String> movedSet = movedOut.toSet();
    final List<ProfileGroup> groups = this.groups
        .map((ProfileGroup g) => g.withoutProfiles(movedSet))
        .toList();
    if (visibleUngrouped == null) return copyWith(groups: groups);

    final List<String> base = mergeVisibleOrder(
      ungrouped,
      visibleUngrouped
          .where(
            (String id) =>
                !movedSet.contains(id) && groupForProfile(id) == null,
          )
          .toList(),
    );
    return copyWith(
      groups: groups,
      ungrouped: <String>[
        ...base.where((String id) => !movedSet.contains(id)),
        ...movedOut,
      ],
    );
  }

  /// Places [profileIds] into [groupId] (null = ungrouped) to match
  /// [sectionOrder]; ids a stale view shows in another folder are skipped.
  ProfileGroupData placeProfiles({
    required List<String> profileIds,
    required String? groupId,
    required List<String> sectionOrder,
  }) {
    final ProfileGroup? target = groupId == null ? null : groupById(groupId);
    if (groupId != null && target == null) return this;
    final Set<String> moved = profileIds.toSet();
    final List<String> targetStored = target?.profileIds ?? ungrouped;
    final Set<String> targetSet = targetStored.toSet();
    final Set<String> claimedElsewhere = <String>{
      for (final ProfileGroup g in groups)
        if (g.uuid != groupId) ...g.profileIds,
    };

    final List<String> order = <String>[];
    for (final String id in sectionOrder) {
      if (order.contains(id)) continue;
      final bool allowed =
          moved.contains(id) ||
          targetSet.contains(id) ||
          (groupId == null && !claimedElsewhere.contains(id));
      if (allowed) order.add(id);
    }
    for (final String id in profileIds) {
      if (!order.contains(id)) order.add(id);
    }

    final List<String> newTarget = mergeVisibleOrder(
      targetStored.where((String id) => !moved.contains(id)).toList(),
      order,
    );

    final ProfileGroupData stripped = withoutProfilesEverywhere(moved);
    if (groupId == null) return stripped.copyWith(ungrouped: newTarget);
    return stripped.copyWith(
      groups: stripped.groups
          .map(
            (ProfileGroup g) =>
                g.uuid == groupId ? g.copyWith(profileIds: newTarget) : g,
          )
          .toList(),
    );
  }

  /// Folders not named in [groupIds] keep their order after the named ones.
  ProfileGroupData withFoldersOrdered(List<String> groupIds) {
    final List<ProfileGroup> ordered = <ProfileGroup>[];
    final Set<String> placed = <String>{};
    for (final String id in groupIds) {
      final ProfileGroup? group = groupById(id);
      if (group != null && placed.add(id)) ordered.add(group);
    }
    for (final ProfileGroup group in groups) {
      if (placed.add(group.uuid)) ordered.add(group);
    }
    return copyWith(groups: ordered);
  }

  /// Reconciles [visible] order into [stored], keeping ids hidden from
  /// [visible] anchored just before the next visible id that followed them.
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

  static const String _groupsKey = 'groups';
  static const String _ungroupedKey = 'ungrouped';

  /// Tolerates malformed blobs: groups without a uuid are dropped, and the
  /// legacy `sortByType` field is ignored.
  factory ProfileGroupData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawGroups = json[_groupsKey] is List
        ? json[_groupsKey] as List<dynamic>
        : const <dynamic>[];
    final List<dynamic> rawUngrouped = json[_ungroupedKey] is List
        ? json[_ungroupedKey] as List<dynamic>
        : const <dynamic>[];

    final Map<String, int> groupIndex = <String, int>{};
    final Set<String> seenIds = <String>{};
    final List<ProfileGroup> groups = <ProfileGroup>[];
    for (final Map raw in rawGroups.whereType<Map>()) {
      final ProfileGroup group = ProfileGroup.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (group.uuid.isEmpty) continue;
      final List<String> ids = group.profileIds.where(seenIds.add).toList();
      final int? first = groupIndex[group.uuid];
      if (first != null) {
        groups[first] = groups[first].withProfiles(ids);
        continue;
      }
      groupIndex[group.uuid] = groups.length;
      groups.add(group.copyWith(profileIds: ids));
    }
    return ProfileGroupData(
      groups: groups,
      ungrouped: rawUngrouped.whereType<String>().where(seenIds.add).toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    _groupsKey: groups.map((ProfileGroup group) => group.toJson()).toList(),
    _ungroupedKey: ungrouped,
  };

  @override
  List<Object?> get props => [groups, ungrouped];

  @override
  String toString() {
    return 'ProfileGroupData(groups: $groups, ungrouped: $ungrouped)';
  }
}
