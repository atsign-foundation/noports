import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';
import 'settings_override_relay_switch.dart';
import 'settings_relay_quick_buttons.dart';

class DefaultRelaySection extends StatelessWidget {
  const DefaultRelaySection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/radio_button.svg'),
            gapW4,
            Text(strings.defaultRelaySelection),
          ],
        ),
        gapH16,
        const CustomContainer.background(
          child: SettingsRelayQuickButtons(),
        ),
        gapH13,
        const CustomContainer.background(
          child: SettingsOverrideRelaySwitch(),
        )
      ],
    );
  }
}
