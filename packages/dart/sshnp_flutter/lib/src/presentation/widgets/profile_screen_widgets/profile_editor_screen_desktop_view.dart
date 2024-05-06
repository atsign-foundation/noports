import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../utility/constants.dart';
import '../../../utility/sizes.dart';
import '../navigation/app_navigation_rail.dart';
import 'profile_form/profile_form_desktop_view.dart';

class ProfileEditorScreenDesktopView extends StatelessWidget {
  const ProfileEditorScreenDesktopView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final strings = AppLocalizations.of(context)!;
    final headlineLarge = Theme.of(context).textTheme.headlineLarge!;
    final bodySmall = Theme.of(context).textTheme.bodySmall!;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.bottomStart,
                children: [
                  Container(
                    color: kDarkBarColor,
                    width: MediaQuery.of(context).size.width,
                    height: Sizes.p60,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: Sizes.p36,
                      top: Sizes.p21,
                      right: Sizes.p48,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        strings.addNewConnection,
                        style: headlineLarge.copyWith(fontSize: headlineLarge.fontSize?.toFont),
                      ),
                      gapH10,
                      const LinearProgressIndicator(
                        value: 0.5,
                      ),
                      gapH10,
                      Text(
                        strings.addNewConnectionDescription,
                        style: bodySmall.copyWith(fontSize: bodySmall.fontSize?.toFont),
                      ),
                      gapH24,
                      const Expanded(child: ProfileFormDesktopView())
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
