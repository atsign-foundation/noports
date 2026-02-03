import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColor.dividerColorAlt)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.p8),
          child: Text(strings.or),
        ),
        const Expanded(child: Divider(color: AppColor.dividerColorAlt)),
      ],
    );
  }
}
