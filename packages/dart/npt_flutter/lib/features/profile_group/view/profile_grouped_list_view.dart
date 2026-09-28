import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
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
import 'package:npt_flutter/widgets/custom_snack_bar.dart';

/// Renders the loaded profile uuids as a flat list, or as custom folders
/// followed by an ungrouped section once any folder exists.
class ProfileGroupedListView extends StatefulWidget {
  final List<String> profiles;

  /// Filters and sorts the connections of each section; null keeps the
  /// manual order.
  final List<String> Function(List<String> uuids)? arrange;
  final bool searching;
  final bool Function(ProfileGroup folder)? folderMatches;
  final int Function(ProfileGroup a, ProfileGroup b)? compareFolders;

  /// False while sorted by name or searching.
  final bool reorderable;

  /// Connections can still be dragged into another folder when not
  /// [reorderable]; the order they are shown in is kept.
  final bool movable;

  /// Shown when the sort puts a drop somewhere else than where it was
  /// released, which would otherwise look like a bug.
  final String? sortedDropMessage;

  const ProfileGroupedListView({
    required this.profiles,
    this.arrange,
    this.searching = false,
    this.folderMatches,
    this.compareFolders,
    this.reorderable = true,
    this.movable = false,
    this.sortedDropMessage,
    super.key,
  });

  static const String ungroupedSectionId =
      ProfileGroupLayout.ungroupedSectionId;

  @override
  State<ProfileGroupedListView> createState() => _ProfileGroupedListViewState();
}

class _DragSession {
  /// Kept fixed during the drag: the list reports indices into it.
  final ProfileGroupLayout layout;
  final int oldIndex;
  final bool isFolder;

  /// The selection travelling with a dragged row; empty for a folder drag.
  final List<String> movedIds;

  /// Released, and applied if it moved; only the drop animation is left.
  bool dropped = false;

  _DragSession({
    required this.layout,
    required this.oldIndex,
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
          return _buildPlain(
            widget.arrange?.call(widget.profiles) ?? widget.profiles,
          );
        }
        final ProfileGroupLayout layout =
            _drag?.layout ?? _layoutFor(_pending ?? groupState.data);
        return _buildReorderable(layout);
      },
    );
  }

  ProfileGroupLayout _layoutFor(ProfileGroupData data) {
    return ProfileGroupLayout.build(
      data: data,
      loaded: widget.profiles,
      collapsed: _collapsed,
      ungroupedTitle: AppLocalizations.of(context)!.groupNoFolder,
      arrange: widget.arrange,
      searching: widget.searching,
      folderMatches: widget.folderMatches,
      compareFolders: widget.compareFolders,
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
    // One drag at a time: a press on a grip during a drag or its drop
    // animation would make the list cancel it.
    final bool dragEnabled = _drag == null;

    Widget buildEntry(BuildContext context, int index) {
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
            // While searching every folder is open, and whenever the order
            // shown isn't the manual one moving would save it, so
            // collapsing and moving are off.
            onToggleCollapsed: widget.searching
                ? null
                : () => setState(() {
                    if (!_collapsed.remove(section.id)) {
                      _collapsed.add(section.id);
                    }
                  }),
            reorderIndex: group != null && widget.reorderable ? index : null,
            dragEnabled: dragEnabled,
            onMoveUp: widget.reorderable && folderIndex > 0
                ? () => _moveFolder(folderIds, folderIndex, -1)
                : null,
            onMoveDown:
                widget.reorderable &&
                    folderIndex >= 0 &&
                    folderIndex < folderIds.length - 1
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
            reorderIndex: widget.reorderable || widget.movable ? index : null,
            dimmed: dimRows,
            dragEnabled: dragEnabled,
          );
      }
    }

    if (!widget.reorderable && !widget.movable) {
      // A plain list, so screen readers aren't offered moves that do nothing.
      return ListView.builder(
        itemCount: layout.entries.length,
        itemBuilder: buildEntry,
      );
    }
    return Listener(
      // A cancelled drag reports neither its end nor a reorder.
      onPointerCancel: (_) {
        if (_drag?.dropped == false) _endDrag();
      },
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: layout.entries.length,
        onReorderStart: (int index) => _onReorderStart(layout, index),
        onReorderEnd: _onReorderEnd,
        onReorderItem: (int oldIndex, int newIndex) =>
            _onReorderItem(layout, oldIndex, newIndex),
        proxyDecorator: _proxyDecorator,
        itemBuilder: buildEntry,
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
        isFolder: entry is ProfileListHeaderEntry,
        movedIds: movedIds,
      );
    });
  }

  /// Fires on pointer release, before the drop animation. The drop is applied
  /// here: autoscroll can still move the gap during the animation, and the
  /// list then reports a different move or none at all.
  void _onReorderEnd(int insertIndex) {
    final _DragSession? session = _drag;
    if (session == null) return;
    session.dropped = true;
    final int oldIndex = session.oldIndex;
    if (insertIndex == oldIndex || insertIndex == oldIndex + 1) return;
    _applyDrop(
      session.layout,
      oldIndex,
      insertIndex > oldIndex ? insertIndex - 1 : insertIndex,
      session,
    );
  }

  /// Fires once the drop animation ends. Also receives screen reader moves,
  /// which arrive without a drag session and are ignored during one.
  void _onReorderItem(ProfileGroupLayout layout, int oldIndex, int newIndex) {
    final _DragSession? session = _drag;
    if (session == null) {
      _applyDrop(layout, oldIndex, newIndex, null);
      return;
    }
    if (oldIndex != session.oldIndex) return;
    if (!session.dropped) {
      _applyDrop(session.layout, oldIndex, newIndex, session);
    }
    _endDrag();
  }

  void _endDrag() {
    if (_drag != null && mounted) setState(() => _drag = null);
  }

  void _applyDrop(
    ProfileGroupLayout layout,
    int oldIndex,
    int newIndex,
    _DragSession? session,
  ) {
    final ProfileGroupEvent? event = layout.resolveDrop(
      oldIndex: oldIndex,
      newIndex: newIndex,
      movedIds: session?.movedIds,
      stepFolders: session == null,
    );
    final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
    final ProfileGroupState state = bloc.state;
    if (event == null || state is! ProfileGroupsLoaded) return;

    final ProfileGroupData current = _pending ?? state.data;
    final ProfileGroupEvent? applied = widget.reorderable
        ? event
        : _intoFolder(event, current);
    if (applied == null) {
      _explainIfMoved(event, _layoutFor(current));
      return;
    }
    final ProfileGroupData next = switch (applied) {
      ProfileGroupPlaceProfilesEvent() => current.placeProfiles(
        profileIds: applied.profileIds,
        groupId: applied.groupId,
        sectionOrder: applied.sectionOrder,
      ),
      ProfileGroupReorderFoldersEvent() => current.withFoldersOrdered(
        applied.groupIds,
      ),
      _ => current,
    };
    if (next == current) return;

    setState(() => _pending = next);
    bloc.add(applied);
    _explainIfMoved(event, _layoutFor(next));
    if ((session?.movedIds.length ?? 0) > 1) {
      context.read<ProfilesSelectedCubit>().deselectAll();
    }
  }

  void _explainIfMoved(ProfileGroupEvent intended, ProfileGroupLayout shown) {
    final String? message = widget.sortedDropMessage;
    if (message == null) return;
    final bool moved = switch (intended) {
      ProfileGroupPlaceProfilesEvent() => _orderDiffers(intended, shown),
      ProfileGroupReorderFoldersEvent() => !listEquals(
        intended.groupIds,
        shown.folderIds,
      ),
      _ => false,
    };
    if (moved) CustomSnackBar.notification(content: message);
  }

  bool _orderDiffers(
    ProfileGroupPlaceProfilesEvent intended,
    ProfileGroupLayout shown,
  ) {
    final String id = intended.groupId ?? ProfileGroupLayout.ungroupedSectionId;
    final ProfileGroupSection? section = shown.sections
        .where((ProfileGroupSection s) => s.id == id)
        .firstOrNull;
    if (section == null) return false;
    final Set<String> inSection = section.uuids.toSet();
    return !listEquals(
      intended.sectionOrder.where(inSection.contains).toList(),
      section.uuids,
    );
  }

  /// While the list is sorted, a drop only moves connections into another
  /// folder, at the end of its manual order. A drop in its own section, or of
  /// a folder, changes nothing.
  ProfileGroupEvent? _intoFolder(
    ProfileGroupEvent event,
    ProfileGroupData data,
  ) {
    if (event is! ProfileGroupPlaceProfilesEvent) return null;
    final String? groupId = event.groupId;
    final List<String> moved = event.profileIds
        .where((String id) => data.groupForProfile(id)?.uuid != groupId)
        .toList();
    if (moved.isEmpty) return null;
    final List<String> manual = groupId == null
        ? data.resolveUngrouped(widget.profiles)
        : data.groupById(groupId)?.profileIds ?? const <String>[];
    return ProfileGroupPlaceProfilesEvent(
      profileIds: moved,
      groupId: groupId,
      sectionOrder: <String>[
        ...manual.where((String id) => !moved.contains(id)),
        ...moved,
      ],
    );
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
    final _DragSession? session = _drag;
    final int count = session?.movedIds.length ?? 0;
    // The proxy goes away at the end of every drag, including the ones the
    // list never reports, so the session can't outlive it.
    return _OnDispose(
      onDispose: () {
        if (identical(_drag, session)) _endDrag();
      },
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOut.transform(animation.value);
          return IgnorePointer(
            child: Material(elevation: lerpDouble(0, 6, t)!, child: child),
          );
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
      ),
    );
  }
}

/// Calls [onDispose] after the frame in which this widget is removed.
class _OnDispose extends StatefulWidget {
  final VoidCallback onDispose;
  final Widget child;
  const _OnDispose({required this.onDispose, required this.child});

  @override
  State<_OnDispose> createState() => _OnDisposeState();
}

class _OnDisposeState extends State<_OnDispose> {
  @override
  void dispose() {
    final VoidCallback onDispose = widget.onDispose;
    WidgetsBinding.instance.addPostFrameCallback((_) => onDispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
