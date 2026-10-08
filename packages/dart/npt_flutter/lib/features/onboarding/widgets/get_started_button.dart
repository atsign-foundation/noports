import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/widgets/get_started_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GetStartedButton extends StatelessWidget {
  const GetStartedButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (context) => const GetStartedDialog(),
        );
      },
      icon: PhosphorIcon(PhosphorIcons.arrowUpRight()),
      label: Text(strings.getStarted),
      iconAlignment: IconAlignment.end,
    );
  }
}
