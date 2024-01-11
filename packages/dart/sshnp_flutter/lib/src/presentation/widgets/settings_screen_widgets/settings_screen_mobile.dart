import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/custom_app_bar.dart';

import '../../../utility/constants.dart';
import '../../../utility/sizes.dart';
import '../contact_tile/contact_list_tile.dart';
import '../custom_list_tile.dart';

class SettingsMobileView extends StatelessWidget {
  const SettingsMobileView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: CustomAppBar(
          title: Text(
        strings.settings,
        style: Theme.of(context).textTheme.headlineLarge,
      )),
      body: Padding(
        padding: const EdgeInsets.only(left: Sizes.p36, right: Sizes.p36, top: Sizes.p21),
        child: ListView(
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            gapH16,
            const Align(
              alignment: Alignment.centerLeft,
              child: ContactListTile(),
            ),
            gapH36,
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                // height: 180,

                decoration: BoxDecoration(
                  color: kProfileBarColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView(shrinkWrap: true, children: const [
                    CustomListTile.keyManagement(),
                    CustomListTile.backUpYourKey(),
                    CustomListTile.switchAtsign(),
                    CustomListTile.resetAtsign(),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
