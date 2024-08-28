import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';
import '../settings.dart';

class DashboardSelectionView extends StatelessWidget {
  const DashboardSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/list_dashes.svg'),
            Text(" Dashboard View", style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
        gapH16,
        const CustomContainer.background(
          child: SettingsViewLayoutSelector(),
        ),
      ],
    );
  }
}
