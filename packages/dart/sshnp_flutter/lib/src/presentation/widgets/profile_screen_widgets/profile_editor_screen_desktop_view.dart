import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../utility/sizes.dart';
import '../navigation/app_navigation_rail.dart';
import 'profile_form/profile_form_desktop_view.dart';

class ProfileEditorScreenDesktopView extends StatelessWidget {
  const ProfileEditorScreenDesktopView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: Sizes.p36,
                  top: Sizes.p21,
                  right: Sizes.p48,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    strings.addNewConnection,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  gapH10,
                  const LinearProgressIndicator(
                    value: 0.5,
                  ),
                  gapH10,
                  Text(
                    strings.addNewConnectionDescription,
                    style: Theme.of(context).textTheme.bodySmall!,
                  ),
                  gapH16,
                  const Expanded(child: ProfileFormDesktopView())
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
