import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_section_header.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_type_resolver.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_row.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileGroupSection {
  final String id;
  final String title;
  final IconData icon;
  final List<String> uuids;
  final ProfileGroup? group;

  const ProfileGroupSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.uuids,
    this.group,
  });
}

/// Renders the loaded profile uuids either as a flat list, as custom folders,
/// or as automatic type buckets depending on [ProfileGroupBloc].
class ProfileGroupedListView extends StatefulWidget {
  final List<String> profiles;
  const ProfileGroupedListView({required this.profiles, super.key});

  static const String ungroupedSectionId = 'ungrouped';
  static const List<ProfileType> typeOrder = <ProfileType>[
    ProfileType.ssh,
    ProfileType.rdp,
    ProfileType.http,
    ProfileType.vnc,
    ProfileType.none,
  ];

  @override
  State<ProfileGroupedListView> createState() => _ProfileGroupedListViewState();
}

class _ProfileGroupedListViewState extends State<ProfileGroupedListView> {
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileGroupBloc, ProfileGroupState>(
      builder: (BuildContext context, ProfileGroupState groupState) {
        if (groupState is! ProfileGroupsLoaded) {
          return _buildFlat(widget.profiles);
        }
        if (groupState.sortByType) {
          return ProfileTypeResolver(
            uuids: widget.profiles,
            builder: (BuildContext context, Map<String, ProfileType> types) {
              return _buildSections(_typeSections(context, types));
            },
          );
        }
        if (groupState.groups.isEmpty) {
          return _buildFlat(widget.profiles);
        }
        return _buildSections(_folderSections(context, groupState.groups));
      },
    );
  }

  List<ProfileGroupSection> _folderSections(
    BuildContext context,
    List<ProfileGroup> groups,
  ) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final Set<String> loaded = widget.profiles.toSet();
    final Set<String> claimed = <String>{};
    final List<ProfileGroupSection> sections = <ProfileGroupSection>[];

    for (final ProfileGroup group in groups) {
      final List<String> uuids = group.profileIds
          .where((String id) => loaded.contains(id) && !claimed.contains(id))
          .toList();
      claimed.addAll(uuids);
      sections.add(
        ProfileGroupSection(
          id: group.uuid,
          title: group.name,
          icon: PhosphorIcons.folder(),
          uuids: uuids,
          group: group,
        ),
      );
    }

    final List<String> ungrouped = widget.profiles
        .where((String id) => !claimed.contains(id))
        .toList();
    if (ungrouped.isNotEmpty) {
      sections.add(
        ProfileGroupSection(
          id: ProfileGroupedListView.ungroupedSectionId,
          title: strings.groupUngrouped,
          icon: PhosphorIcons.folderDashed(),
          uuids: ungrouped,
        ),
      );
    }
    return sections;
  }

  List<ProfileGroupSection> _typeSections(
    BuildContext context,
    Map<String, ProfileType> types,
  ) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<ProfileGroupSection> sections = <ProfileGroupSection>[];
    for (final ProfileType type in ProfileGroupedListView.typeOrder) {
      final List<String> uuids = widget.profiles
          .where((String id) => (types[id] ?? ProfileType.none) == type)
          .toList();
      if (uuids.isEmpty) continue;
      sections.add(
        ProfileGroupSection(
          id: 'type-${type.name}',
          title: _typeTitle(strings, type),
          icon: _typeIcon(type),
          uuids: uuids,
        ),
      );
    }
    return sections;
  }

  static String _typeTitle(AppLocalizations strings, ProfileType type) {
    return switch (type) {
      ProfileType.ssh => strings.groupTypeSsh,
      ProfileType.rdp => strings.groupTypeRdp,
      ProfileType.http => strings.groupTypeHttp,
      ProfileType.vnc => strings.groupTypeVnc,
      ProfileType.none => strings.groupTypeNone,
    };
  }

  static IconData _typeIcon(ProfileType type) {
    return switch (type) {
      ProfileType.ssh => PhosphorIcons.terminal(),
      ProfileType.rdp => PhosphorIcons.desktop(),
      ProfileType.http => PhosphorIcons.globe(),
      ProfileType.vnc => PhosphorIcons.monitor(),
      ProfileType.none => PhosphorIcons.folderDashed(),
    };
  }

  Widget _buildFlat(List<String> profiles) {
    return ListView.builder(
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: profiles.length,
      itemBuilder: (BuildContext context, int index) {
        return ProfileListRow(
          key: ValueKey<String>('ProfileListRow-${profiles[index]}'),
          uuid: profiles[index],
        );
      },
    );
  }

  Widget _buildSections(List<ProfileGroupSection> sections) {
    final List<Object> entries = <Object>[];
    for (final ProfileGroupSection section in sections) {
      entries.add(section);
      if (!_collapsed.contains(section.id)) {
        entries.addAll(section.uuids);
      }
    }

    return ListView.builder(
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final Object entry = entries[index];
        if (entry is ProfileGroupSection) {
          return ProfileGroupSectionHeader(
            key: ValueKey<String>('ProfileGroupSectionHeader-${entry.id}'),
            title: entry.title,
            icon: entry.icon,
            uuids: entry.uuids,
            group: entry.group,
            collapsed: _collapsed.contains(entry.id),
            onToggleCollapsed: () {
              setState(() {
                if (!_collapsed.remove(entry.id)) _collapsed.add(entry.id);
              });
            },
          );
        }
        final String uuid = entry as String;
        return ProfileListRow(
          key: ValueKey<String>('ProfileListRow-$uuid'),
          uuid: uuid,
        );
      },
    );
  }
}
