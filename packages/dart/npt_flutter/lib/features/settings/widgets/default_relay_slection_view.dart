import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';
import 'settings_override_relay_switch.dart';
import 'settings_relay_quick_buttons.dart';

class DefaultRelaySelectionView extends StatelessWidget {
  const DefaultRelaySelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/radio_button.svg'),
            Text(" Default Relay Selection", style: Theme.of(context).textTheme.bodyLarge),
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
