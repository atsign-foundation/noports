import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/settings_language_selector.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';

class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.public_outlined),
            gapW4,
            Text(strings.language),
          ],
        ),
        gapH16,
        const CustomContainer.background(child: SettingsLanguageSelector()),
      ],
    );
  }
}
