import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/util/profile_folder_layout.dart';
import 'package:npt_flutter/features/profile_folder/widgets/profile_folder_section_header.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_selected_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_row.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileFolderListView extends StatefulWidget {
  final List<String> profiles;

  final List<String> Function(List<String> uuids)? arrange;
  final bool searching;
  final bool Function(ProfileFolder folder)? folderMatches;
  final int Function(ProfileFolder a, ProfileFolder b)? compareFolders;

  final bool reorderable;

  /// Rows can still move to another folder when not [reorderable].
  final bool movable;

  final String? sortedDropMessage;

  const ProfileFolderListView({
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

  static const String unfiledSectionId = ProfileFolderLayout.unfiledSectionId;

  @override
  State<ProfileFolderListView> createState() => _ProfileFolderListViewState();
}

class _DragSession {
  /// Kept fixed during the drag: the list reports indices into it.
  final ProfileFolderLayout layout;
  final int oldIndex;
  final bool isFolder;

  final List<String> movedIds;

  bool dropped = false;

  _DragSession({
    required this.layout,
    required this.oldIndex,
    required this.isFolder,
    required this.movedIds,
  });
}

class _ProfileFolderListViewState extends State<ProfileFolderListView> {
  /// Shared by every list, so swapping one for another keeps the scroll
  /// position.
  static const PageStorageKey<String> _scrollKey = PageStorageKey<String>(
    'ProfileFolderListView',
  );

  /// Cleared when the folders unload: the list that would end it is gone.
  _DragSession? _drag;

  /// Shown until the bloc emits it, so a dropped row doesn't jump back.
  ProfileFolderData? _pending;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileFolderBloc, ProfileFolderState>(
      listener: (BuildContext context, ProfileFolderState state) {
        if (state is! ProfileFoldersLoaded) {
          _drag = null;
        }
        if (_pending != null || state is! ProfileFoldersLoaded) {
          setState(() => _pending = null);
        }
      },
      builder: (BuildContext context, ProfileFolderState folderState) {
        if (folderState is ProfileFoldersLoading) {
          return const Center(child: Spinner());
        }
        if (folderState is! ProfileFoldersLoaded) {
          return _buildPlain(
            widget.arrange?.call(widget.profiles) ?? widget.profiles,
          );
        }
        final ProfileFolderLayout layout =
            _drag?.layout ?? _layoutFor(_pending ?? folderState.data);
        return _buildReorderable(layout, folderState.editable);
      },
    );
  }

  ProfileFolderLayout _layoutFor(ProfileFolderData data) {
    return ProfileFolderLayout.build(
      data: data,
      loaded: widget.profiles,
      collapsed: <String>{
        for (final ProfileFolder folder in data.folders)
          if (folder.collapsed) folder.uuid,
        if (data.unfiledCollapsed) ProfileFolderLayout.unfiledSectionId,
      },
      unfiledTitle: AppLocalizations.of(context)!.folderNone,
      arrange: widget.arrange,
      searching: widget.searching,
      folderMatches: widget.folderMatches,
      compareFolders: widget.compareFolders,
    );
  }

  Widget _buildPlain(List<String> profiles) {
    return ListView.builder(
      key: _scrollKey,
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

  /// Keeps an empty Unfiled header, hidden until a row drag: a change in item
  /// count cancels a drag.
  Widget _buildReorderable(ProfileFolderLayout layout, bool editable) {
    final bool reorderable = widget.reorderable && editable;
    final bool movable = widget.movable && editable;
    final List<String> folderIds = layout.folderIds;
    final List<ProfileFolder> shownFolders = <ProfileFolder>[
      for (final ProfileFolderSection section in layout.sections)
        if (section.folder != null) section.folder!,
    ];
    bool canPrecede(ProfileFolder a, ProfileFolder b) =>
        (widget.compareFolders?.call(a, b) ?? 0) <= 0;
    final Set<String> loaded = widget.profiles.toSet();
    final bool dimRows = _drag?.isFolder ?? false;
    final bool rowDragging = _drag != null && !_drag!.isFolder;
    final bool dragEnabled = _drag == null;

    Widget buildEntry(BuildContext context, int index) {
      final ProfileListEntry entry = layout.entries[index];
      switch (entry) {
        case ProfileListHeaderEntry(:final ProfileFolderSection section):
          final ProfileFolder? folder = section.folder;
          final int folderIndex = folder == null
              ? -1
              : folderIds.indexOf(folder.uuid);
          final bool shown =
              folder != null || section.uuids.isNotEmpty || rowDragging;
          final int? totalWhileSearching = widget.searching && folder != null
              ? folder.profileIds.where(loaded.contains).length
              : null;
          final Widget header = ProfileFolderSectionHeader(
            title: section.title,
            icon: section.icon,
            uuids: section.uuids,
            total: totalWhileSearching,
            folder: folder,
            collapsed: layout.collapsed.contains(section.id),
            onToggleCollapsed: widget.searching
                ? null
                : () => context.read<ProfileFolderBloc>().add(
                    ProfileFolderSetCollapsedEvent(
                      folderId: folder?.uuid,
                      collapsed: !layout.collapsed.contains(section.id),
                    ),
                  ),
            reorderIndex: folder != null && reorderable ? index : null,
            dragEnabled: dragEnabled,
            editable: editable,
            onMoveUp:
                reorderable &&
                    folderIndex > 0 &&
                    canPrecede(folder!, shownFolders[folderIndex - 1])
                ? () => _moveFolder(folderIds, folderIndex, -1)
                : null,
            onMoveDown:
                reorderable &&
                    folderIndex >= 0 &&
                    folderIndex < folderIds.length - 1 &&
                    canPrecede(shownFolders[folderIndex + 1], folder!)
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
            reorderIndex: reorderable || movable ? index : null,
            dimmed: dimRows,
            dragEnabled: dragEnabled,
          );
      }
    }

    /// ReorderableListView would still offer screen readers moves.
    final bool nothingMoves = !reorderable && !movable;
    if (nothingMoves) {
      return ListView.builder(
        key: _scrollKey,
        itemCount: layout.entries.length,
        itemBuilder: buildEntry,
      );
    }
    return Listener(
      onPointerCancel: (_) => _endCancelledDrag(),
      child: ReorderableListView.builder(
        key: _scrollKey,
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

  void _onReorderStart(ProfileFolderLayout layout, int index) {
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

  /// Applied on release: autoscroll can still move the gap afterwards.
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

  /// Fires after the drop animation. Screen reader moves arrive here too.
  void _onReorderItem(ProfileFolderLayout layout, int oldIndex, int newIndex) {
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
    ProfileFolderLayout layout,
    int oldIndex,
    int newIndex,
    _DragSession? session,
  ) {
    final ProfileFolderEvent? event = layout.resolveDrop(
      oldIndex: oldIndex,
      newIndex: newIndex,
      movedIds: session?.movedIds,
      stepFolders: session == null,
    );
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileFolderState state = bloc.state;
    if (event == null || state is! ProfileFoldersLoaded) return;

    final ProfileFolderData current = _pending ?? state.data;
    final ProfileFolderEvent? applied = widget.reorderable
        ? _inManualOrder(event, current, layout.entries[oldIndex])
        : _intoFolder(event, current);
    if (applied == null) {
      _explainIfMoved(event, _layoutFor(current));
      return;
    }
    final ProfileFolderData next = switch (applied) {
      ProfileFolderPlaceProfilesEvent() => current.placeProfiles(
        profileIds: applied.profileIds,
        folderId: applied.folderId,
        sectionOrder: applied.sectionOrder,
      ),
      ProfileFolderReorderEvent() => current.withFoldersOrdered(
        applied.folderIds,
      ),
      _ => current,
    };
    final bool dropMatchesSaved = next == current;
    if (dropMatchesSaved) {
      _explainIfMoved(event, _layoutFor(current));
      return;
    }

    setState(() => _pending = next);
    bloc.add(applied);
    _explainIfMoved(event, _layoutFor(next));
    if ((session?.movedIds.length ?? 0) > 1) {
      context.read<ProfilesSelectedCubit>().deselectAll();
    }
  }

  void _explainIfMoved(ProfileFolderEvent intended, ProfileFolderLayout shown) {
    final String? message = widget.sortedDropMessage;
    if (message == null) return;
    final bool moved = switch (intended) {
      ProfileFolderPlaceProfilesEvent() => _orderDiffers(intended, shown),
      ProfileFolderReorderEvent() => !listEquals(
        intended.folderIds,
        shown.folderIds,
      ),
      _ => false,
    };
    if (moved) CustomSnackBar.notification(content: message);
  }

  bool _orderDiffers(
    ProfileFolderPlaceProfilesEvent intended,
    ProfileFolderLayout shown,
  ) {
    final String id = intended.folderId ?? ProfileFolderLayout.unfiledSectionId;
    final ProfileFolderSection? section = shown.sections
        .where((ProfileFolderSection s) => s.id == id)
        .firstOrNull;
    if (section == null) return false;
    final Set<String> inSection = section.uuids.toSet();
    return !listEquals(
      intended.sectionOrder.where(inSection.contains).toList(),
      section.uuids,
    );
  }

  /// While sorted, a drop only moves connections to the end of another folder.
  ProfileFolderEvent? _intoFolder(
    ProfileFolderEvent event,
    ProfileFolderData data,
  ) {
    if (event is! ProfileFolderPlaceProfilesEvent) return null;
    final String? folderId = event.folderId;
    final List<String> moved = event.profileIds
        .where((String id) => data.folderForProfile(id)?.uuid != folderId)
        .toList();
    if (moved.isEmpty) return null;
    final List<String> manual = folderId == null
        ? data.resolveUnfiled(widget.profiles)
        : data.folderById(folderId)?.profileIds ?? const <String>[];
    return ProfileFolderPlaceProfilesEvent(
      profileIds: moved,
      folderId: folderId,
      sectionOrder: <String>[
        ...manual.where((String id) => !moved.contains(id)),
        ...moved,
      ],
    );
  }

  /// With favorites lifted, the drop is placed in the manual order.
  ProfileFolderEvent? _inManualOrder(
    ProfileFolderEvent event,
    ProfileFolderData data,
    ProfileListEntry grabbed,
  ) {
    switch (event) {
      case ProfileFolderPlaceProfilesEvent(:final String? folderId)
          when widget.arrange != null:
        final List<String> Function(List<String>) arrange = widget.arrange!;
        final List<String> manual = folderId == null
            ? data.resolveUnfiled(widget.profiles)
            : data.folderById(folderId)?.profileIds ?? const <String>[];
        bool sortKeepsBothOrders(String a, String b) =>
            listEquals(arrange(<String>[a, b]), <String>[a, b]) &&
            listEquals(arrange(<String>[b, a]), <String>[b, a]);
        final List<String> order = ProfileFolderData.placeInManualOrder(
          manual: manual,
          released: event.sectionOrder,
          moved: event.profileIds,
          tie: sortKeepsBothOrders,
        );
        if (listEquals(order, manual)) return null;
        return ProfileFolderPlaceProfilesEvent(
          profileIds: event.profileIds,
          folderId: folderId,
          sectionOrder: order,
        );
      case ProfileFolderReorderEvent(:final List<String> folderIds)
          when grabbed is ProfileListHeaderEntry &&
              grabbed.section.folder != null:
        final List<String> order = _foldersInManualOrder(
          folderIds,
          grabbed.section.folder!,
          data,
        );
        if (listEquals(order, <String>[
          for (final ProfileFolder f in data.folders) f.uuid,
        ])) {
          return null;
        }
        return ProfileFolderReorderEvent(order);
      default:
        return event;
    }
  }

  List<String> _foldersInManualOrder(
    List<String> released,
    ProfileFolder moved,
    ProfileFolderData data,
  ) {
    final int Function(ProfileFolder a, ProfileFolder b)? compare =
        widget.compareFolders;
    if (compare == null) return released;
    return ProfileFolderData.placeInManualOrder(
      manual: <String>[for (final ProfileFolder f in data.folders) f.uuid],
      released: released,
      moved: <String>[moved.uuid],
      tie: (String a, String b) {
        final ProfileFolder? folderA = data.folderById(a);
        final ProfileFolder? folderB = data.folderById(b);
        return folderA == null ||
            folderB == null ||
            compare(folderA, folderB) == 0;
      },
    );
  }

  void _moveFolder(List<String> folderIds, int index, int delta) {
    final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
    final ProfileFolderState state = bloc.state;
    if (state is! ProfileFoldersLoaded) return;
    final ProfileFolderData data = _pending ?? state.data;
    final List<String> order = List<String>.of(folderIds);
    final String movedId = order.removeAt(index);
    order.insert(index + delta, movedId);
    final ProfileFolder? moved = data.folderById(movedId);
    if (moved == null) return;
    bloc.add(
      ProfileFolderReorderEvent(_foldersInManualOrder(order, moved, data)),
    );
  }

  /// A cancelled drag reports neither its end nor a reorder.
  void _endCancelledDrag() {
    if (_drag?.dropped == false) _endDrag();
  }

  /// Ends the drag when the proxy goes away, even if the list never reports it.
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    final _DragSession? session = _drag;
    final int count = session?.movedIds.length ?? 0;
    return _OnDispose(
      onDispose: () {
        if (identical(_drag, session)) _endDrag();
      },
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOut.transform(animation.value);
          return IgnorePointer(
            child: Material(elevation: 6 * t, child: child),
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
