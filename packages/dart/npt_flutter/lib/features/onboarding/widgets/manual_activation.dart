import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ManualActivation extends StatelessWidget {
  /// A widget which shows the manual entry flow for activation, allowing the user to enter the atsign and root domain information manually to complete activation without using an activation file.
  const ManualActivation({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final titleMedium = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(color: Colors.black);

    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      spacing: Sizes.p10,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            strings.activationManual,
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.black),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.selectorTitleAtsign, style: titleMedium),
            Text(strings.selectorSubTitleAtsign, style: bodySmall),
            gapH16,
            const AtsignSelector(isInSignInFlow: false),
          ],
        ),

        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.selectorTitleRootDomain,
              style: titleMedium.copyWith(color: Colors.black),
            ),
            Text(strings.selectorSubTitleRootDomain, style: bodySmall),
            gapH16,
            const AtDirectorySelector(),
          ],
        ),
      ],
    );
  }
}
