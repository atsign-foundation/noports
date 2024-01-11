import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/custom_app_bar.dart';

import '../../../utility/constants.dart';
import '../../../utility/sizes.dart';
import '../custom_list_tile.dart';

class SupportScreenMobileView extends StatelessWidget {
  const SupportScreenMobileView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: CustomAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.support,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              strings.supportDescription,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21, right: Sizes.p36),
        child: ListView(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p20),
              ),
              color: kProfileBarColor,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: CustomListTile.discord(
                        tileColor: kProfileBarColor,
                      ),
                    ),
                    Flexible(
                      child: CustomListTile.email(tileColor: kProfileBarColor),
                    ),
                  ],
                ),
              ),
            ),
            gapH20,
            const Divider(
              color: kProfileFormFieldColor,
              thickness: Sizes.p3,
            ),
            gapH20,
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p20),
              ),
              color: kProfileBarColor,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: CustomListTile.faq(tileColor: kProfileBarColor),
                    ),
                    Flexible(
                      child: CustomListTile.privacyPolicy(tileColor: kProfileBarColor),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
