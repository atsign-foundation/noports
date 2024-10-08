import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class OnboardingDialog extends StatelessWidget {
  const OnboardingDialog(
      {required this.title,
      required this.subtitle,
      required this.successButtonText,
      required this.children,
      super.key});
  final String title;
  final String subtitle;
  final String successButtonText;
  final List<Widget> children;

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
                  Text(title),
                  Text(subtitle),
                  gapH16,
                  ...children,
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
                  child: Text(successButtonText),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
