import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';

class AtDirectoryDialog extends StatelessWidget {
  const AtDirectoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return OnboardingDialog(
      title: strings.atDirectory,
      subtitle: strings.atDirectorySubtitle,
      successButtonText: strings.done,
      children: [
        OnboardingAtDirectorySelector(),
      ],
    );
  }
}
