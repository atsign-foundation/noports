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
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Text(
                    strings.supportDescription,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: kTextColorDark),
                  ),
                  gapH30,
                  const Flexible(
                    child: Row(
                      children: [
                        Flexible(child: CustomListTile.discord()),
                        Flexible(child: CustomListTile.email()),
                      ],
                    ),
                  ),
                  gapH20,
                  const Divider(
                    color: kProfileFormFieldColor,
                  ),
                  gapH20,
                  const Flexible(
                    child: Row(
                      children: [
                        Flexible(child: CustomListTile.faq()),
                        Flexible(child: CustomListTile.privacyPolicy()),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
