import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

sealed class ProfileFolderPick {
  const ProfileFolderPick();
}

final class ProfileFolderPickUnfiled extends ProfileFolderPick {
  const ProfileFolderPickUnfiled();
}

final class ProfileFolderPickNew extends ProfileFolderPick {
  const ProfileFolderPickNew();
}

final class ProfileFolderPickExisting extends ProfileFolderPick {
  final String folderId;
  const ProfileFolderPickExisting(this.folderId);
}

/// Lets the user choose a destination folder. Pops with a [ProfileFolderPick],
/// or null when dismissed.
class ProfileFolderPickerDialog extends StatelessWidget {
  final List<ProfileFolder> folders;

  /// Null is "No folder".
  final String? currentFolderId;

  /// False when the connections are in different places: none is marked.
  final bool hasCurrent;
  const ProfileFolderPickerDialog({
    required this.folders,
    this.currentFolderId,
    this.hasCurrent = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return SimpleDialog(
      title: Text(strings.folderMoveToFolder),
      children: <Widget>[
        for (final ProfileFolder folder in folders)
          _PickOption(
            key: Key('ProfileFolderPickerDialog-${folder.uuid}'),
            icon: PhosphorIcons.folder(),
            label: folder.name,
            selected: hasCurrent && folder.uuid == currentFolderId,
            onPressed: () => Navigator.of(
              context,
            ).pop(ProfileFolderPickExisting(folder.uuid)),
          ),
        if (folders.isNotEmpty) const Divider(height: Sizes.p1),
        _PickOption(
          key: const Key('ProfileFolderPickerDialog-none'),
          icon: PhosphorIcons.folderDashed(),
          label: strings.folderNone,
          selected: hasCurrent && currentFolderId == null,
          onPressed: () =>
              Navigator.of(context).pop(const ProfileFolderPickUnfiled()),
        ),
        _PickOption(
          key: const Key('ProfileFolderPickerDialog-new'),
          icon: PhosphorIcons.folderPlus(),
          label: strings.folderNew,
          selected: false,
          onPressed: () =>
              Navigator.of(context).pop(const ProfileFolderPickNew()),
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
