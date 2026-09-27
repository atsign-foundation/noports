part of 'profile_list_filter_cubit.dart';

final class ProfileListFilterState extends Loggable {
  final String query;
  final ProfileSortMode sortMode;
  final bool favoritesFirst;

  /// Loaded profiles, followed only while searching or sorting by name.
  final Map<String, Profile> profiles;

  /// Followed profiles that failed to load.
  final Set<String> failed;

  /// Folders, so a search can also match their names.
  final List<ProfileGroup> folders;

  const ProfileListFilterState({
    this.query = '',
    this.sortMode = ProfileSortMode.manual,
    this.favoritesFirst = false,
    this.profiles = const <String, Profile>{},
    this.failed = const <String>{},
    this.folders = const <ProfileGroup>[],
  });

  bool get searching => query.trim().isNotEmpty;

  bool get needsProfiles => searching || sortMode != ProfileSortMode.manual;

  bool get isDefault => !searching && !reordered;

  /// The shown order differs from the manual one, so it can't be dragged.
  bool get reordered => sortMode != ProfileSortMode.manual || favoritesFirst;

  bool settled(String uuid) =>
      profiles.containsKey(uuid) || failed.contains(uuid);

  /// Loaded and known not to match, as opposed to still loading.
  bool hides(String uuid) =>
      searching && profiles.containsKey(uuid) && !matches(uuid);

  /// A folder whose name matches shows all of its connections.
  bool folderMatches(ProfileGroup folder) =>
      searching && folder.name.toLowerCase().contains(_needle);

  bool get anyFolderMatches => folders.any(folderMatches);

  bool matches(String uuid) {
    if (!searching) return true;
    for (final ProfileGroup folder in folders) {
      if (folder.containsProfile(uuid) && folderMatches(folder)) return true;
    }
    final Profile? profile = profiles[uuid];
    if (profile == null) return false;
    final String needle = _needle;
    return profile.displayName.toLowerCase().contains(needle) ||
        '${profile.deviceName}${profile.sshnpdAtsign ?? ''}'
            .toLowerCase()
            .contains(needle);
  }

  String get _needle => query.trim().toLowerCase();

  /// Filters [uuids] by the query and sorts them, keeping the given order
  /// between equal entries.
  List<String> apply(Iterable<String> uuids, Set<String> favorites) {
    final List<String> shown = uuids.where(matches).toList();
    if (!reordered) return shown;
    final Map<String, int> position = <String, int>{
      for (int i = 0; i < shown.length; i++) shown[i]: i,
    };
    final Map<String, String> names = <String, String>{
      for (final String uuid in shown)
        uuid: profiles[uuid]?.displayName.toLowerCase() ?? '',
    };
    shown.sort((String a, String b) {
      if (favoritesFirst) {
        final int byFavorite = (favorites.contains(a) ? 0 : 1).compareTo(
          favorites.contains(b) ? 0 : 1,
        );
        if (byFavorite != 0) return byFavorite;
      }
      final int byName = switch (sortMode) {
        ProfileSortMode.manual => 0,
        ProfileSortMode.nameAscending => names[a]!.compareTo(names[b]!),
        ProfileSortMode.nameDescending => names[b]!.compareTo(names[a]!),
      };
      return byName != 0 ? byName : position[a]!.compareTo(position[b]!);
    });
    return shown;
  }

  ProfileListFilterState copyWith({
    String? query,
    ProfileSortMode? sortMode,
    bool? favoritesFirst,
    Map<String, Profile>? profiles,
    Set<String>? failed,
    List<ProfileGroup>? folders,
  }) {
    return ProfileListFilterState(
      query: query ?? this.query,
      sortMode: sortMode ?? this.sortMode,
      favoritesFirst: favoritesFirst ?? this.favoritesFirst,
      profiles: profiles ?? this.profiles,
      failed: failed ?? this.failed,
      folders: folders ?? this.folders,
    );
  }

  @override
  List<Object?> get props => [
    query,
    sortMode,
    favoritesFirst,
    profiles,
    failed,
    folders,
  ];

  @override
  String toString() {
    return 'ProfileListFilterState(query: $query, sortMode: $sortMode, '
        'favoritesFirst: $favoritesFirst, profiles: ${profiles.length})';
  }
}
