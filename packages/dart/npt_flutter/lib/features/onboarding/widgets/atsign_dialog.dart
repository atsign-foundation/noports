import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';

class AtSignDialog extends StatelessWidget {
  const AtSignDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return OnboardingDialog(
      title: strings.atsignDialogTitle,
      subtitle: strings.atsignDialogSubtitle,
      successButtonText: strings.next,
      children: const [
        AtsignSelector(),
      ],
    );
  }
}
