import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/sizes.dart';
import '../../../widgets/custom_container.dart';
import '../settings.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/list_dashes.svg'),
            gapW4,
            Text(strings.dashboardView),
          ],
        ),
        gapH16,
        const CustomContainer.background(
          child: SettingsDashboardLayoutSelector(),
        ),
      ],
    );
  }
}
