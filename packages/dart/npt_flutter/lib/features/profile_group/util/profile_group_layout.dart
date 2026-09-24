import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileGroupSection {
  final String id;
  final String title;
  final IconData icon;

  final List<String> uuids;

  /// Null for the ungrouped section.
  final ProfileGroup? group;

  const ProfileGroupSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.uuids,
    this.group,
  });
}

sealed class ProfileListEntry {
  const ProfileListEntry();

  ProfileGroupSection get section;

  /// ReorderableListView requires a key per item; tests also key off it.
  Key get key;
}

final class ProfileListHeaderEntry extends ProfileListEntry {
  @override
  final ProfileGroupSection section;
  const ProfileListHeaderEntry(this.section);

  @override
  Key get key => ValueKey<String>('ProfileGroupSectionHeader-${section.id}');
}

final class ProfileListRowEntry extends ProfileListEntry {
  final String uuid;
  @override
  final ProfileGroupSection section;
  const ProfileListRowEntry(this.uuid, this.section);

  @override
  Key get key => ValueKey<String>('ProfileListRow-$uuid');
}

class ProfileGroupLayout {
  static const String ungroupedSectionId = 'ungrouped';

  /// The ungrouped section is always present, even when empty.
  final List<ProfileGroupSection> sections;

  final List<ProfileListEntry> entries;

  final bool showHeaders;

  /// The collapsed sections [entries] was built with; drops resolve against it.
  final Set<String> collapsed;

  const ProfileGroupLayout._(
    this.sections,
    this.entries,
    this.showHeaders,
    this.collapsed,
  );

  factory ProfileGroupLayout.build({
    required ProfileGroupData data,
    required List<String> loaded,
    required Set<String> collapsed,
    required String ungroupedTitle,
  }) {
    final Set<String> loadedSet = loaded.toSet();
    final Set<String> claimed = <String>{};
    final List<ProfileGroupSection> sections = <ProfileGroupSection>[];

    for (final ProfileGroup group in data.groups) {
      sections.add(
        ProfileGroupSection(
          id: group.uuid,
          title: group.name,
          icon: PhosphorIcons.folder(),
          uuids: group.profileIds
              .where((String id) => loadedSet.contains(id) && claimed.add(id))
              .toList(),
          group: group,
        ),
      );
    }
    sections.add(
      ProfileGroupSection(
        id: ungroupedSectionId,
        title: ungroupedTitle,
        icon: PhosphorIcons.folderDashed(),
        uuids: data.resolveUngrouped(loaded),
      ),
    );

    final bool showHeaders = data.groups.isNotEmpty;
    final List<ProfileListEntry> entries = <ProfileListEntry>[];
    for (final ProfileGroupSection section in sections) {
      if (showHeaders) entries.add(ProfileListHeaderEntry(section));
      if (showHeaders && collapsed.contains(section.id)) continue;
      for (final String uuid in section.uuids) {
        entries.add(ProfileListRowEntry(uuid, section));
      }
    }
    return ProfileGroupLayout._(
      sections,
      entries,
      showHeaders,
      Set<String>.unmodifiable(collapsed),
    );
  }

  List<String> get folderIds => <String>[
    for (final ProfileGroupSection section in sections)
      if (section.group != null) section.group!.uuid,
  ];

  List<String> inDisplayOrder(Set<String> ids) => <String>[
    for (final ProfileGroupSection section in sections)
      for (final String uuid in section.uuids)
        if (ids.contains(uuid)) uuid,
  ];

  /// Maps a drop from `ReorderableListView.onReorderItem` to the bloc event
  /// that applies it, or null if nothing changes. [stepFolders] is for screen
  /// reader moves, which shift one entry: a folder then moves one place.
  ProfileGroupEvent? resolveDrop({
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
      case ProfileListHeaderEntry(:final ProfileGroupSection section):
        if (section.group == null) return null;
        final List<String> order = <String>[
          for (final ProfileListEntry e in after)
            if (e is ProfileListHeaderEntry && e.section.group != null)
              e.section.group!.uuid,
        ];
        if (!listEquals(order, folderIds)) {
          return ProfileGroupReorderFoldersEvent(order);
        }
        if (!stepFolders || target == oldIndex) return null;
        final List<String> stepped = List<String>.of(folderIds);
        final int from = stepped.indexOf(section.group!.uuid);
        final int to = from + (target < oldIndex ? -1 : 1);
        if (to < 0 || to >= stepped.length) return null;
        stepped
          ..removeAt(from)
          ..insert(to, section.group!.uuid);
        return ProfileGroupReorderFoldersEvent(stepped);

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
        final ProfileGroupSection section = headerIndex >= 0
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
        return ProfileGroupPlaceProfilesEvent(
          profileIds: travelling,
          groupId: section.group?.uuid,
          sectionOrder: order,
        );
    }
  }
}
