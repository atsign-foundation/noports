import 'package:flutter/material.dart';
import 'package:npt_flutter/features/settings/widgets/settings_language_selector.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';

class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Icon(Icons.public_outlined),
            Text(" Language"),
          ],
        ),
        gapH16,
        CustomContainer.background(
          child: SettingsLanguageSelector(),
        ),
      ],
    );
  }
}
