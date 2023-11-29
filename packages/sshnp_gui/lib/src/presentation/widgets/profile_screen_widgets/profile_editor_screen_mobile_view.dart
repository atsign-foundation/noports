import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_form/profile_form_mobile_view.dart';
import 'package:sshnp_gui/src/utility/constants.dart';

import '../../../utility/sizes.dart';

class ProfileEditorScreenMobileView extends StatelessWidget {
  const ProfileEditorScreenMobileView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackGroundColorDark,
        title: Text(
          strings.addNewConnection,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: Sizes.p36,
            top: Sizes.p4,
            right: Sizes.p48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.addNewConnectionDescription,
                style: Theme.of(context).textTheme.bodySmall!,
              ),
              gapH10,
              const LinearProgressIndicator(
                value: 0.5,
              ),
              gapH16,
              const Expanded(child: ProfileFormMobileView())
            ],
          ),
        ),
      ),
    );
  }
}
