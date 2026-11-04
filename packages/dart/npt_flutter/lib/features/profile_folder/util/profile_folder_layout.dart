import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileFolderSection {
  final String id;
  final String title;
  final IconData icon;

  final List<String> uuids;

  /// Null for the unfiled section.
  final ProfileFolder? folder;

  const ProfileFolderSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.uuids,
    this.folder,
  });
}

sealed class ProfileListEntry {
  const ProfileListEntry();

  ProfileFolderSection get section;

  /// ReorderableListView needs a key per item.
  Key get key;
}

final class ProfileListHeaderEntry extends ProfileListEntry {
  @override
  final ProfileFolderSection section;
  const ProfileListHeaderEntry(this.section);

  @override
  Key get key => ValueKey<String>('ProfileFolderSectionHeader-${section.id}');
}

final class ProfileListRowEntry extends ProfileListEntry {
  final String uuid;
  @override
  final ProfileFolderSection section;
  const ProfileListRowEntry(this.uuid, this.section);

  @override
  Key get key => ValueKey<String>('ProfileListRow-$uuid');
}

class ProfileFolderLayout {
  static const String unfiledSectionId = 'unfiled';

  /// The unfiled section is always present, even when empty.
  final List<ProfileFolderSection> sections;

  final List<ProfileListEntry> entries;

  final bool showHeaders;

  final Set<String> collapsed;

  const ProfileFolderLayout._(
    this.sections,
    this.entries,
    this.showHeaders,
    this.collapsed,
  );

  /// While [searching], folders without a match are left out unless
  /// [folderMatches], and none is collapsed.
  factory ProfileFolderLayout.build({
    required ProfileFolderData data,
    required List<String> loaded,
    required Set<String> collapsed,
    required String unfiledTitle,
    List<String> Function(List<String> uuids)? arrange,
    bool searching = false,
    bool Function(ProfileFolder folder)? folderMatches,
    int Function(ProfileFolder a, ProfileFolder b)? compareFolders,
  }) {
    final Set<String> loadedSet = loaded.toSet();
    final Set<String> claimed = <String>{};
    final List<ProfileFolderSection> sections = <ProfileFolderSection>[];

    final List<ProfileFolder> folders = List<ProfileFolder>.of(data.folders);
    if (compareFolders != null) {
      final Map<String, int> position = <String, int>{
        for (int i = 0; i < folders.length; i++) folders[i].uuid: i,
      };
      folders.sort((ProfileFolder a, ProfileFolder b) {
        final int byOrder = compareFolders(a, b);
        return byOrder != 0
            ? byOrder
            : position[a.uuid]!.compareTo(position[b.uuid]!);
      });
    }
    for (final ProfileFolder folder in folders) {
      sections.add(
        ProfileFolderSection(
          id: folder.uuid,
          title: folder.name,
          icon: PhosphorIcons.folder(),
          uuids: _arranged(
            folder.profileIds
                .where((String id) => loadedSet.contains(id) && claimed.add(id))
                .toList(),
            arrange,
          ),
          folder: folder,
        ),
      );
    }
    sections.add(
      ProfileFolderSection(
        id: unfiledSectionId,
        title: unfiledTitle,
        icon: PhosphorIcons.folderDashed(),
        uuids: _arranged(data.resolveUnfiled(loaded), arrange),
      ),
    );

    final bool showHeaders = data.folders.isNotEmpty;
    final List<ProfileListEntry> entries = <ProfileListEntry>[];
    for (final ProfileFolderSection section in sections) {
      if (searching &&
          section.folder != null &&
          section.uuids.isEmpty &&
          !(folderMatches?.call(section.folder!) ?? false)) {
        continue;
      }
      if (showHeaders) entries.add(ProfileListHeaderEntry(section));
      if (showHeaders && !searching && collapsed.contains(section.id)) {
        continue;
      }
      for (final String uuid in section.uuids) {
        entries.add(ProfileListRowEntry(uuid, section));
      }
    }
    return ProfileFolderLayout._(
      sections,
      entries,
      showHeaders,
      Set<String>.unmodifiable(searching ? const <String>{} : collapsed),
    );
  }

  static List<String> _arranged(
    List<String> uuids,
    List<String> Function(List<String> uuids)? arrange,
  ) => arrange == null ? uuids : arrange(uuids);

  List<String> get folderIds => <String>[
    for (final ProfileFolderSection section in sections)
      if (section.folder != null) section.folder!.uuid,
  ];

  List<String> inDisplayOrder(Set<String> ids) => <String>[
    for (final ProfileFolderSection section in sections)
      for (final String uuid in section.uuids)
        if (ids.contains(uuid)) uuid,
  ];

  /// Maps a drop to the bloc event that applies it, or null if nothing changes.
  /// [stepFolders] moves a folder one place, as screen reader moves do.
  ProfileFolderEvent? resolveDrop({
    required int oldIndex,
    required int newIndex,
    List<String>? movedIds,
    bool stepFolders = false,
  }) {
    if (oldIndex < 0 || oldIndex >= entries.length) return null;
    final int target = newIndex.clamp(0, entries.length - 1);
    final ProfileListEntry moved = entries[oldIndex];
    final List<ProfileListEntry> after = List<ProfileListEntry>.of(entries)
      ..removeAt(oldIndex)
      ..insert(target, moved);

    switch (moved) {
      case ProfileListHeaderEntry(:final ProfileFolderSection section):
        if (section.folder == null) return null;
        final List<String> order = <String>[
          for (final ProfileListEntry e in after)
            if (e is ProfileListHeaderEntry && e.section.folder != null)
              e.section.folder!.uuid,
        ];
        if (!listEquals(order, folderIds)) {
          return ProfileFolderReorderEvent(order);
        }
        if (!stepFolders || target == oldIndex) return null;
        final List<String> stepped = List<String>.of(folderIds);
        final int from = stepped.indexOf(section.folder!.uuid);
        final int to = from + (target < oldIndex ? -1 : 1);
        if (to < 0 || to >= stepped.length) return null;
        stepped
          ..removeAt(from)
          ..insert(to, section.folder!.uuid);
        return ProfileFolderReorderEvent(stepped);

      case ProfileListRowEntry(:final String uuid):
        final List<String> travelling =
            (movedIds != null && movedIds.contains(uuid))
            ? movedIds
            : <String>[uuid];
        final Set<String> travellingSet = travelling.toSet();

        int headerIndex = -1;
        for (int i = target - 1; i >= 0; i--) {
          if (after[i] is ProfileListHeaderEntry) {
            headerIndex = i;
            break;
          }
        }
        final ProfileFolderSection section = headerIndex >= 0
            ? after[headerIndex].section
            : sections.first;
        final List<String> rest = section.uuids
            .where((String id) => !travellingSet.contains(id))
            .toList();

        final List<String> order;
        if (showHeaders && headerIndex < 0) {
          // Above the first header: top of the first section.
          order = <String>[...travelling, ...rest];
        } else if (showHeaders && collapsed.contains(section.id)) {
          // A collapsed folder shows no rows to drop between, so append.
          order = <String>[...rest, ...travelling];
        } else {
          order = <String>[];
          for (int i = headerIndex + 1; i < after.length; i++) {
            final ProfileListEntry e = after[i];
            if (e is ProfileListHeaderEntry) break;
            final String id = (e as ProfileListRowEntry).uuid;
            if (id == uuid) {
              order.addAll(travelling);
            } else if (!travellingSet.contains(id)) {
              order.add(id);
            }
          }
        }
        return ProfileFolderPlaceProfilesEvent(
          profileIds: travelling,
          folderId: section.folder?.uuid,
          sectionOrder: order,
        );
    }
  }
}
