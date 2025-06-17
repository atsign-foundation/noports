import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/widgets/enrollment_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

enum APKAMFlow {
  atKeys,
  apkam,
}

class ApkamChoiceDialog extends StatelessWidget {
  const ApkamChoiceDialog({super.key});

  static const _kButtonWidth = 170.0;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return EnrollmentDialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.authenticate,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black),
          ),
          gapH4,
          Text(
            strings.selectEnrollMethod,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          gapH16,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.uploadKey,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      Text(
                        strings.uploadKeyDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                gapW16,
                SizedBox(
                  width: _kButtonWidth,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: Sizes.p18,
                      ),
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: Sizes.p32, vertical: Sizes.p20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Sizes.p8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(APKAMFlow.atKeys);
                    },
                    child: Text(strings.selectKey),
                  ),
                )
              ],
            ),
          ),
          gapH16,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.enrollWithAuthenticator,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      Text(
                        strings.enrollWithAuthenticatorDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                gapH16,
                SizedBox(
                  width: _kButtonWidth,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: Sizes.p18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: Sizes.p32, vertical: Sizes.p20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Sizes.p8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(APKAMFlow.apkam);
                    },
                    child: Text(strings.enroll),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
