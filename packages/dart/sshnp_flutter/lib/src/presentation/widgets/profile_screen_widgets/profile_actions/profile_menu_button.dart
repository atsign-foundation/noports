import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_callbacks.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class ProfileMenuButton extends ConsumerStatefulWidget {
  final String profileName;
  const ProfileMenuButton(this.profileName, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileMenuButton> createState() => _ProfileMenuBarState();
}

class _ProfileMenuBarState extends ConsumerState<ProfileMenuButton> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return PopupMenuButton(
      itemBuilder: (context) => [
        // PopupMenuItem(
        //   child: ProfileMenuItem(
        //       const Icon(Icons.file_download_outlined), strings.export),
        //   onTap: () =>
        //       ProfileActionCallbacks.export(ref, context, widget.profileName),
        // ),
        PopupMenuItem(
          child: ProfileMenuItem(const Icon(Icons.edit), strings.edit),
          onTap: () => ProfileActionCallbacks.edit(ref, context, widget.profileName),
        ),
        PopupMenuItem(
          child: const ProfileMenuItem(Icon(Icons.delete_forever), 'Delete'),
          onTap: () => ProfileActionCallbacks.delete(context, widget.profileName),
        ),
      ],
      padding: EdgeInsets.zero,
    );
  }
}

class ProfileMenuItem extends StatelessWidget {
  final Widget icon;
  final String text;
  const ProfileMenuItem(this.icon, this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        gapW12,
        Text(text),
      ],
    );
  }
}
