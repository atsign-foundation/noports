import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_start_queue_cubit.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/util/profile_folder_actions.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_drag_handle.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/confirmation_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileFolderSectionHeader extends StatelessWidget {
  /// Same widths as a row's star and menu, so the columns line up.
  static const double _slotWidth = Sizes.p40;

  final String title;
  final IconData icon;
  final List<String> uuids;

  /// How many the folder holds when [uuids] is only the part a search shows.
  final int? total;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  /// Null for the unfiled section.
  final ProfileFolder? folder;

  final int? reorderIndex;
  final bool dragEnabled;

  /// False turns off everything that changes the folder.
  final bool editable;

  /// Null disables the menu item.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const ProfileFolderSectionHeader({
    required this.title,
    required this.icon,
    required this.uuids,
    this.total,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.folder,
    this.reorderIndex,
    this.dragEnabled = true,
    this.editable = true,
    this.onMoveUp,
    this.onMoveDown,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: AppColor.surfaceColor,
        border: Border(bottom: BorderSide(color: AppColor.dividerColorAlt)),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: Sizes.p2,
        horizontal: Sizes.p10,
      ),
      child: Row(
        children: <Widget>[
          ProfileDragHandle(index: reorderIndex, enabled: dragEnabled),
          IconButton(
            tooltip: collapsed ? strings.folderExpand : strings.folderCollapse,
            onPressed: onToggleCollapsed,
            icon: PhosphorIcon(
              collapsed
                  ? PhosphorIcons.caretRight()
                  : PhosphorIcons.caretDown(),
              size: Sizes.p16,
            ),
          ),
          PhosphorIcon(icon, size: Sizes.p20),
          gapW8,
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                gapW8,
                Text(
                  '${uuids.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColor.onSurfaceColor,
                  ),
                ),
              ],
            ),
          ),
          _StartStopButtons(uuids: uuids, total: total, folder: folder),
          SizedBox(
            width: _slotWidth,
            child: folder == null
                ? null
                : IconButton(
                    tooltip: folder!.favorite
                        ? strings.favoriteRemove
                        : strings.favoriteAdd,
                    onPressed: editable
                        ? () => context.read<ProfileFolderBloc>().add(
                            ProfileFolderSetFavoriteEvent(
                              folderId: folder!.uuid,
                              favorite: !folder!.favorite,
                            ),
                          )
                        : null,
                    icon: PhosphorIcon(
                      folder!.favorite
                          ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                          : PhosphorIcons.star(),
                      color: folder!.favorite
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
          ),
          // Fixed slots keep start/stop buttons aligned across headers.
          SizedBox(
            width: _slotWidth,
            child: folder == null
                ? null
                : _ProfileFolderMenuButton(
                    folder: folder!,
                    editable: editable,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StartStopButtons extends StatelessWidget {
  final List<String> uuids;
  final int? total;
  final ProfileFolder? folder;
  const _StartStopButtons({
    required this.uuids,
    required this.total,
    required this.folder,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<String> startable = uuids
        .where((String uuid) => folder?.startsWithAll(uuid) ?? true)
        .toList();
    return BlocBuilder<ProfileStartQueueCubit, ProfileStartQueueState>(
      builder: (BuildContext context, ProfileStartQueueState queue) {
        final List<String> waiting = queue.waiting;
        final bool anyWaiting = uuids.any(waiting.contains);
        return BlocBuilder<ProfilesRunningCubit, ProfilesRunningState>(
          buildWhen: (ProfilesRunningState a, ProfilesRunningState b) =>
              uuids.any(
                (String uuid) =>
                    a.socketConnectors.containsKey(uuid) !=
                    b.socketConnectors.containsKey(uuid),
              ),
          builder: (BuildContext context, ProfilesRunningState running) {
            bool isRunning(String uuid) =>
                running.socketConnectors.containsKey(uuid);
            final bool canStart = startable.any(
              (String uuid) => !isRunning(uuid) && !waiting.contains(uuid),
            );
            final bool canStop = uuids.any(isRunning) || anyWaiting;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: startable.length < (total ?? uuids.length)
                      ? strings.folderStartSome(
                          startable.length,
                          total ?? uuids.length,
                        )
                      : strings.folderStartAll,
                  onPressed: canStart
                      ? () => ProfileFolderActions.startAll(context, startable)
                      : null,
                  icon: PhosphorIcon(
                    PhosphorIcons.play(PhosphorIconsStyle.fill),
                    size: Sizes.p20,
                    color: canStart ? AppColor.successColor : null,
                  ),
                ),
                IconButton(
                  tooltip: strings.folderStopAll,
                  onPressed: canStop
                      ? () => ProfileFolderActions.stopAll(context, uuids)
                      : null,
                  icon: PhosphorIcon(
                    PhosphorIcons.stop(PhosphorIconsStyle.fill),
                    size: Sizes.p20,
                    color: canStop ? AppColor.errorColor : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfileFolderMenuButton extends StatelessWidget {
  final ProfileFolder folder;
  final bool editable;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  const _ProfileFolderMenuButton({
    required this.folder,
    required this.editable,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return PopupMenuButton<PopupMenuEntry>(
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext _) {
        return <PopupMenuEntry<PopupMenuEntry>>[
          PopupMenuItem(
            enabled: editable,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.plusSquare()),
                gapW10,
                Text(strings.folderAddConnection),
              ],
            ),
            onTap: () =>
                ProfileFolderActions.addConnectionToFolder(folder.uuid),
          ),
          PopupMenuItem(
            enabled: editable,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.listChecks()),
                gapW10,
                Flexible(
                  child: Text(
                    strings.folderChooseStartAll,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            onTap: () => ProfileFolderActions.chooseStartAll(context, folder),
          ),
          PopupMenuItem(
            enabled: editable,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.pencil()),
                gapW10,
                Text(strings.folderRename),
              ],
            ),
            onTap: () => ProfileFolderActions.renameFolder(context, folder),
          ),
          PopupMenuItem(
            enabled: onMoveUp != null,
            onTap: onMoveUp,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.arrowUp()),
                gapW10,
                Text(strings.folderMoveUp),
              ],
            ),
          ),
          PopupMenuItem(
            enabled: onMoveDown != null,
            onTap: onMoveDown,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.arrowDown()),
                gapW10,
                Text(strings.folderMoveDown),
              ],
            ),
          ),
          PopupMenuItem(
            enabled: editable,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.trash()),
                gapW10,
                Text(strings.folderDelete),
              ],
            ),
            onTap: () {
              final ProfileFolderBloc bloc = context.read<ProfileFolderBloc>();
              showDialog(
                context: context,
                builder: (BuildContext _) => ConfirmationDialog(
                  message: strings.folderDeleteMessage,
                  actionText: strings.delete,
                  action: () {
                    bloc.add(
                      ProfileFolderDeleteEvent(
                        folderId: folder.uuid,
                        // Read on confirm, not when the dialog opened.
                        visibleUnfiled: context.mounted
                            ? ProfileFolderActions.visibleUnfiled(context)
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ];
      },
    );
  }
}
