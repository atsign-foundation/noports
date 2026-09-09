import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

sealed class ProfileGroupPick {
  const ProfileGroupPick();
}

final class ProfileGroupPickNone extends ProfileGroupPick {
  const ProfileGroupPickNone();
}

final class ProfileGroupPickNew extends ProfileGroupPick {
  const ProfileGroupPickNew();
}

final class ProfileGroupPickExisting extends ProfileGroupPick {
  final String groupId;
  const ProfileGroupPickExisting(this.groupId);
}

/// Lets the user choose a destination folder. Pops with a [ProfileGroupPick],
/// or null when dismissed.
class ProfileGroupPickerDialog extends StatelessWidget {
  final List<ProfileGroup> groups;
  final String? currentGroupId;
  const ProfileGroupPickerDialog({
    required this.groups,
    this.currentGroupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return SimpleDialog(
      title: Text(strings.groupMoveToFolder),
      children: <Widget>[
        for (final ProfileGroup group in groups)
          _PickOption(
            key: Key('ProfileGroupPickerDialog-${group.uuid}'),
            icon: PhosphorIcons.folder(),
            label: group.name,
            selected: group.uuid == currentGroupId,
            onPressed: () =>
                Navigator.of(context).pop(ProfileGroupPickExisting(group.uuid)),
          ),
        if (groups.isNotEmpty) const Divider(height: Sizes.p1),
        _PickOption(
          key: const Key('ProfileGroupPickerDialog-none'),
          icon: PhosphorIcons.folderDashed(),
          label: strings.groupNoFolder,
          selected: currentGroupId == null,
          onPressed: () =>
              Navigator.of(context).pop(const ProfileGroupPickNone()),
        ),
        _PickOption(
          key: const Key('ProfileGroupPickerDialog-new'),
          icon: PhosphorIcons.folderPlus(),
          label: strings.groupNewFolder,
          selected: false,
          onPressed: () =>
              Navigator.of(context).pop(const ProfileGroupPickNew()),
        ),
      ],
    );
  }
}

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  const _PickOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onPressed,
      child: Row(
        children: <Widget>[
          PhosphorIcon(
            icon,
            size: Sizes.p20,
            color: selected ? AppColor.primaryColor : null,
          ),
          gapW10,
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
