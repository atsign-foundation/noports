import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';

enum ProfileType {
  ssh,
  rdp,
  http,
  vnc,
  none;

  static ProfileType fromProtocol(String? protocol) {
    return switch (protocol?.toLowerCase()) {
      'ssh' => ProfileType.ssh,
      'rdp' => ProfileType.rdp,
      'http' || 'https' => ProfileType.http,
      'vnc' => ProfileType.vnc,
      _ => ProfileType.none,
    };
  }

  static ProfileType fromProfile(Profile profile) {
    if (profile.connectUriProtocol != null) {
      return fromProtocol(profile.connectUriProtocol);
    }
    final String? legacyUri = profile.connectUri;
    if (legacyUri == null || legacyUri.isEmpty) return ProfileType.none;
    return fromProtocol(Uri.tryParse(legacyUri)?.scheme);
  }
}

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

final class ProfileGroupData extends Loggable {
  final List<ProfileGroup> groups;
  final bool sortByType;

  const ProfileGroupData({
    this.groups = const <ProfileGroup>[],
    this.sortByType = false,
  });

  ProfileGroupData copyWith({List<ProfileGroup>? groups, bool? sortByType}) {
    return ProfileGroupData(
      groups: groups ?? this.groups,
      sortByType: sortByType ?? this.sortByType,
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

  static const String _groupsKey = 'groups';
  static const String _sortByTypeKey = 'sortByType';

  factory ProfileGroupData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawGroups = json[_groupsKey] is List
        ? json[_groupsKey] as List<dynamic>
        : const <dynamic>[];
    return ProfileGroupData(
      groups: rawGroups
          .whereType<Map>()
          .map(
            (Map raw) => ProfileGroup.fromJson(Map<String, dynamic>.from(raw)),
          )
          .where((ProfileGroup group) => group.uuid.isNotEmpty)
          .toList(),
      sortByType: json[_sortByTypeKey] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    _groupsKey: groups.map((ProfileGroup group) => group.toJson()).toList(),
    _sortByTypeKey: sortByType,
  };

  @override
  List<Object?> get props => [groups, sortByType];

  @override
  String toString() {
    return 'ProfileGroupData(sortByType: $sortByType, groups: $groups)';
  }
}
