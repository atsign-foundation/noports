import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/presentation/widgets/home_screen_widgets/home_screen_actions/home_screen_action_callbacks.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class HomeScreenMenuButton extends ConsumerStatefulWidget {
  const HomeScreenMenuButton({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenMenuButton> createState() => _ProfileMenuBarState();
}

class _ProfileMenuBarState extends ConsumerState<HomeScreenMenuButton> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return PopupMenuButton(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ProfileMenuItem(const Icon(Icons.upload), strings.import),
          onTap: () => HomeScreenActionCallbacks.import(ref, context),
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
