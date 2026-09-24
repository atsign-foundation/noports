import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/util/profile_group_layout.dart';
import 'package:npt_flutter/features/profile_group/widgets/profile_group_section_header.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_selected_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_row.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

/// Renders the loaded profile uuids as a flat list, or as custom folders
/// followed by an ungrouped section once any folder exists.
class ProfileGroupedListView extends StatefulWidget {
  final List<String> profiles;
  const ProfileGroupedListView({required this.profiles, super.key});

  static const String ungroupedSectionId =
      ProfileGroupLayout.ungroupedSectionId;

  @override
  State<ProfileGroupedListView> createState() => _ProfileGroupedListViewState();
}

class _DragSession {
  /// Kept fixed during the drag: the list reports indices into it.
  final ProfileGroupLayout layout;
  final int oldIndex;
  final Key draggedKey;
  final bool isFolder;

  /// The selection travelling with a dragged row; empty for a folder drag.
  final List<String> movedIds;

  const _DragSession({
    required this.layout,
    required this.oldIndex,
    required this.draggedKey,
    required this.isFolder,
    required this.movedIds,
  });
}

class _ProfileGroupedListViewState extends State<ProfileGroupedListView> {
  final Set<String> _collapsed = <String>{};
  _DragSession? _drag;

  /// Shown until the bloc emits it, so a dropped row doesn't jump back.
  ProfileGroupData? _pending;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileGroupBloc, ProfileGroupState>(
      listener: (BuildContext context, ProfileGroupState state) {
        if (state is! ProfileGroupsLoaded) {
          // The list is being replaced; its callbacks won't fire again.
          _drag = null;
        }
        if (_pending != null || state is! ProfileGroupsLoaded) {
          setState(() => _pending = null);
        }
      },
      builder: (BuildContext context, ProfileGroupState groupState) {
        if (groupState is! ProfileGroupsLoaded) {
          return _buildPlain(widget.profiles);
        }
        final ProfileGroupLayout layout =
            _drag?.layout ??
            ProfileGroupLayout.build(
              data: _pending ?? groupState.data,
              loaded: widget.profiles,
              collapsed: _collapsed,
              ungroupedTitle: AppLocalizations.of(context)!.groupNoFolder,
            );
        return _buildReorderable(layout);
      },
    );
  }

  Widget _buildPlain(List<String> profiles) {
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

  Widget _buildReorderable(ProfileGroupLayout layout) {
    final List<String> folderIds = layout.folderIds;
    final bool dimRows = _drag?.isFolder ?? false;
    // Item count must stay fixed during a drag or it gets cancelled, so the
    // empty ungrouped header stays in the list and only shows on a drag.
    final bool rowDragging = _drag != null && !_drag!.isFolder;

    return Listener(
      // A cancelled drag reports neither its end nor a reorder.
      onPointerCancel: (_) => _endDrag(),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: layout.entries.length,
        onReorderStart: (int index) => _onReorderStart(layout, index),
        onReorderEnd: _onReorderEnd,
        onReorderItem: (int oldIndex, int newIndex) =>
            _onReorderItem(layout, oldIndex, newIndex),
        proxyDecorator: _proxyDecorator,
        itemBuilder: (BuildContext context, int index) {
          final ProfileListEntry entry = layout.entries[index];
          switch (entry) {
            case ProfileListHeaderEntry(:final ProfileGroupSection section):
              final ProfileGroup? group = section.group;
              final int folderIndex = group == null
                  ? -1
                  : folderIds.indexOf(group.uuid);
              final bool shown =
                  group != null || section.uuids.isNotEmpty || rowDragging;
              final Widget header = ProfileGroupSectionHeader(
                title: section.title,
                icon: section.icon,
                uuids: section.uuids,
                group: group,
                collapsed: layout.collapsed.contains(section.id),
                onToggleCollapsed: () => setState(() {
                  if (!_collapsed.remove(section.id)) {
                    _collapsed.add(section.id);
                  }
                }),
                reorderIndex: group != null ? index : null,
                onMoveUp: folderIndex > 0
                    ? () => _moveFolder(folderIds, folderIndex, -1)
                    : null,
                onMoveDown:
                    folderIndex >= 0 && folderIndex < folderIds.length - 1
                    ? () => _moveFolder(folderIds, folderIndex, 1)
                    : null,
              );
              return ClipRect(
                key: entry.key,
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: shown ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: ExcludeSemantics(
                    excluding: !shown,
                    child: IgnorePointer(ignoring: !shown, child: header),
                  ),
                ),
              );
            case ProfileListRowEntry(:final String uuid):
              return ProfileListRow(
                key: entry.key,
                uuid: uuid,
                reorderIndex: index,
                dimmed: dimRows,
              );
          }
        },
      ),
    );
  }

  void _onReorderStart(ProfileGroupLayout layout, int index) {
    final ProfileListEntry entry = layout.entries[index];
    List<String> movedIds = const <String>[];
    if (entry is ProfileListRowEntry) {
      final Set<String> selected = context
          .read<ProfilesSelectedCubit>()
          .state
          .selected;
      movedIds = selected.length > 1 && selected.contains(entry.uuid)
          ? layout.inDisplayOrder(selected)
          : <String>[entry.uuid];
    }
    setState(() {
      _drag = _DragSession(
        layout: layout,
        oldIndex: index,
        draggedKey: entry.key,
        isFolder: entry is ProfileListHeaderEntry,
        movedIds: movedIds,
      );
    });
  }

  /// Fires on pointer release. A drop back where the item started never
  /// reaches [_onReorderItem], so it ends the drag here instead.
  void _onReorderEnd(int insertIndex) {
    final _DragSession? session = _drag;
    if (session == null) return;
    if (insertIndex == session.oldIndex ||
        insertIndex == session.oldIndex + 1) {
      _endDrag();
    }
  }

  void _endDrag() {
    if (_drag != null && mounted) setState(() => _drag = null);
  }

  /// Also receives screen reader moves, which arrive without a drag session.
  void _onReorderItem(ProfileGroupLayout layout, int oldIndex, int newIndex) {
    final _DragSession? session =
        _drag != null &&
            oldIndex < layout.entries.length &&
            layout.entries[oldIndex].key == _drag!.draggedKey
        ? _drag
        : null;

    final ProfileGroupEvent? event = layout.resolveDrop(
      oldIndex: oldIndex,
      newIndex: newIndex,
      movedIds: session?.movedIds,
      stepFolders: session == null,
    );
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    final ProfileGroupState state = bloc.state;
    if (event == null || state is! ProfileGroupsLoaded) {
      _endDrag();
      return;
    }

    final ProfileGroupData current = _pending ?? state.data;
    final ProfileGroupData next = switch (event) {
      ProfileGroupPlaceProfilesEvent() => current.placeProfiles(
        profileIds: event.profileIds,
        groupId: event.groupId,
        sectionOrder: event.sectionOrder,
      ),
      ProfileGroupReorderFoldersEvent() => current.withFoldersOrdered(
        event.groupIds,
      ),
      _ => current,
    };
    final bool changed = next != current;
    final bool movedSelection = (session?.movedIds.length ?? 0) > 1;

    setState(() {
      _drag = null;
      if (changed) _pending = next;
    });
    if (!changed) return;
    bloc.add(event);
    if (movedSelection) context.read<ProfilesSelectedCubit>().deselectAll();
  }

  void _moveFolder(List<String> folderIds, int index, int delta) {
    final List<String> order = List<String>.of(folderIds);
    final String moved = order.removeAt(index);
    order.insert(index + delta, moved);
    context.read<ProfileGroupBloc>().add(
      ProfileGroupReorderFoldersEvent(order),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    final int count = _drag?.movedIds.length ?? 0;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(animation.value);
        return Material(elevation: lerpDouble(0, 6, t)!, child: child);
      },
      child: count > 1
          ? Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                child,
                Positioned(
                  top: Sizes.p4,
                  left: Sizes.p4,
                  child: _CountBadge(count: count),
                ),
              ],
            )
          : child,
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ProfileDragCountBadge'),
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p6,
        vertical: Sizes.p2,
      ),
      decoration: BoxDecoration(
        color: AppColor.primaryColor,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
