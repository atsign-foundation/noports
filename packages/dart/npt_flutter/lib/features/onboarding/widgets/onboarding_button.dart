import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/widgets/get_started_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final strings = AppLocalizations.of(App.navState.currentContext!)!;

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({super.key});

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

enum _OnboardingButtonStatus { ready, loading }

class _OnboardingButtonState extends State<OnboardingButton> {
  _OnboardingButtonStatus buttonStatus = _OnboardingButtonStatus.ready;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () async {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const GetStartedDialog(),
        );
      },
      icon: PhosphorIcon(
        key: const Key('getStartedIcon'),
        PhosphorIcons.arrowUpRight(),
      ),
      label: Text(strings.getStarted),
      iconAlignment: IconAlignment.end,
    );
  }
}
