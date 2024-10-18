import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class OnboardingDialog extends StatelessWidget {
  const OnboardingDialog({required this.options, super.key});
  final Map<String, AtsignInformation> options;

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
                  const Text("Select or type the client atSign"),
                  gapH16,
                  AtsignSelector(
                    options: options,
                  ),
                  gapH16,
                  const Text("Select or type the root domain"),
                  AtDirectorySelector(
                    options: options,
                  ),
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
                  child: const Text("Next"),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
