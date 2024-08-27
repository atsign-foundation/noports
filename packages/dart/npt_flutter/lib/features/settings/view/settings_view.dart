import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/logging.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/settings/widgets/contact_list_tile.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../styles/sizes.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsInitial) {
          context.read<SettingsBloc>().add(const SettingsLoadEvent());
        }
        switch (state) {
          case SettingsInitial():
          case SettingsLoading():
            return const Spinner();
          case SettingsLoadedState():
            return const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 92, left: 120, right: 77),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: Sizes.p192,
                    child: CustomCard.settingsContent(
                      child: Column(children: [
                        SettingsErrorHint(),
                        Text("Default Relay"),
                        SettingsRelayAtSignTextField(),
                        SettingsRelayQuickButtons(),
                        SettingsOverrideRelaySwitch(),
                        SizedBox(height: 100),
                        Text("View Mode"),
                        SettingsViewLayoutSelector(),
                        Text("Advanced"),
                        Row(children: [
                          Text("Enable Logging"),
                          EnableLogsBox(),
                          ExportLogsButton(),
                        ]),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: CustomCard.settingsRail(
                      child: Padding(
                        padding: EdgeInsets.all(0.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            gapH30,
                            CustomTextButton.discord(),
                            CustomTextButton.email(),
                            CustomTextButton.faq(),
                            CustomTextButton.privacyPolicy(),
                            CustomTextButton.feedback(),
                            CustomTextButton.backUpYourKey(),
                            CustomTextButton.resetAtsign(),
                            ContactListTile(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: Sizes.p470,
                    child: Text('@ 2024 Atsign, All Rights Reserved'),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}
