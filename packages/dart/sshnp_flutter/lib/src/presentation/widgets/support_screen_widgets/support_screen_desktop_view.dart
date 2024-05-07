import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../utility/constants.dart';
import '../../../utility/sizes.dart';
import '../custom_list_tile.dart';
import '../navigation/app_navigation_rail.dart';

class SupportScreenDesktopView extends StatelessWidget {
  const SupportScreenDesktopView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final headlineLarge = Theme.of(context).textTheme.headlineLarge!;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Sizes.p20),
                    child: Text(
                      strings.support,
                      style: headlineLarge.copyWith(
                        fontSize: headlineLarge.fontSize!.toFont,
                      ),
                    ),
                  ),
                  Text(
                    strings.supportDescription,
                    style: bodyMedium.copyWith(
                      color: kTextColorDark,
                      fontSize: bodyMedium.fontSize!.toFont,
                    ),
                  ),
                  gapH30,
                  const Row(
                    children: [
                      Flexible(child: CustomListTile.discord()),
                      gapW12,
                      Flexible(child: CustomListTile.email()),
                    ],
                  ),
                  gapH20,
                  const Divider(
                    color: kProfileFormFieldColor,
                  ),
                  gapH20,
                  const Row(
                    children: [
                      Flexible(child: CustomListTile.faq()),
                      gapW12,
                      Flexible(child: CustomListTile.privacyPolicy()),
                    ],
                  ),
                  gapH20,
                  const Divider(
                    color: kProfileFormFieldColor,
                  ),
                  gapH20,
                  const Row(
                    children: [
                      Flexible(child: CustomListTile.feedback()),
                      gapW12,
                      Flexible(child: gap0),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
