import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_at_directory_selector.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class AtDirectoryDialog extends StatefulWidget {
  const AtDirectoryDialog({super.key});

  @override
  State<AtDirectoryDialog> createState() => _AtDirectoryDialogState();
}

class _AtDirectoryDialogState extends State<AtDirectoryDialog> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: Colors.white,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sizes.p12, horizontal: Sizes.p16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomContainer.background(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.atDirectory),
                  Text(strings.atDirectorySubtitle),
                  gapH16,
                  OnboardingAtDirectorySelector(),
                ],
              ),
            ),
            gapH10,
            CustomContainer.background(
                child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(strings.cancel),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text(strings.onboard),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
