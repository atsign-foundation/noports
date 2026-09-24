import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/util/profile_group_actions.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_running_cubit.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_drag_handle.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/confirmation_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileGroupSectionHeader extends StatelessWidget {
  static const double _menuSlotWidth = 48;

  final String title;
  final IconData icon;
  final List<String> uuids;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  /// Null for the ungrouped section.
  final ProfileGroup? group;

  final int? reorderIndex;

  /// Move the folder one place up or down. Null disables the menu item.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const ProfileGroupSectionHeader({
    required this.title,
    required this.icon,
    required this.uuids,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.group,
    this.reorderIndex,
    this.onMoveUp,
    this.onMoveDown,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: Sizes.p2,
        horizontal: Sizes.p10,
      ),
      child: Row(
        children: <Widget>[
          ProfileDragHandle(index: reorderIndex),
          IconButton(
            tooltip: collapsed ? strings.groupExpand : strings.groupCollapse,
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
          BlocSelector<ProfilesRunningCubit, ProfilesRunningState, int>(
            selector: (ProfilesRunningState state) => uuids
                .where(
                  (String uuid) => state.socketConnectors.containsKey(uuid),
                )
                .length,
            builder: (BuildContext context, int running) {
              final bool canStart = uuids.isNotEmpty && running < uuids.length;
              final bool canStop = running > 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: strings.groupStartAll,
                    onPressed: canStart
                        ? () => ProfileGroupActions.startAll(context, uuids)
                        : null,
                    icon: PhosphorIcon(
                      PhosphorIcons.play(PhosphorIconsStyle.fill),
                      size: Sizes.p20,
                      color: canStart ? AppColor.successColor : null,
                    ),
                  ),
                  IconButton(
                    tooltip: strings.groupStopAll,
                    onPressed: canStop
                        ? () => ProfileGroupActions.stopAll(context, uuids)
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
          ),
          // Fixed slot keeps start/stop buttons aligned across headers.
          SizedBox(
            width: _menuSlotWidth,
            child: group == null
                ? null
                : _ProfileGroupMenuButton(
                    group: group!,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileGroupMenuButton extends StatelessWidget {
  final ProfileGroup group;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  const _ProfileGroupMenuButton({
    required this.group,
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
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.plusSquare()),
                gapW10,
                Text(strings.groupAddConnection),
              ],
            ),
            onTap: () => ProfileGroupActions.addConnectionToFolder(group.uuid),
          ),
          PopupMenuItem(
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.pencil()),
                gapW10,
                Text(strings.groupRename),
              ],
            ),
            onTap: () => ProfileGroupActions.renameFolder(context, group),
          ),
          PopupMenuItem(
            enabled: onMoveUp != null,
            onTap: onMoveUp,
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.arrowUp()),
                gapW10,
                Text(strings.groupMoveUp),
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
                Text(strings.groupMoveDown),
              ],
            ),
          ),
          PopupMenuItem(
            child: Row(
              children: <Widget>[
                PhosphorIcon(PhosphorIcons.trash()),
                gapW10,
                Text(strings.groupDeleteFolder),
              ],
            ),
            onTap: () {
              final ProfileGroupBloc bloc = context.read<ProfileGroupBloc>();
              showDialog(
                context: context,
                builder: (BuildContext _) => ConfirmationDialog(
                  message: strings.groupDeleteFolderMessage,
                  actionText: strings.delete,
                  action: () {
                    bloc.add(
                      ProfileGroupDeleteEvent(
                        groupId: group.uuid,
                        // Read on confirm, not when the dialog opened.
                        visibleUngrouped: context.mounted
                            ? ProfileGroupActions.visibleUngrouped(context)
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
