import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/settings/widgets/advance_section.dart';
import 'package:npt_flutter/features/settings/widgets/contact_list_tile.dart';
import 'package:npt_flutter/features/settings/widgets/default_relay_section.dart';
import 'package:npt_flutter/features/settings/widgets/language_section.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../styles/sizes.dart';
import '../widgets/dashboard_section.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final deviceSize = MediaQuery.of(context).size;
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsInitial) {
          context.read<SettingsBloc>().add(const SettingsLoadEvent());
        }
        switch (state) {
          case SettingsInitial():
          case SettingsLoading():
            return const Center(child: Spinner());
          case SettingsLoadedState():
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomCard.settingsRail(
                      height: deviceSize.height * Sizes.SettingsCardHeightFactor,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // gapH30,
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
                    CustomCard.settingsContent(
                      height: deviceSize.height * Sizes.SettingsCardHeightFactor,
                      width: deviceSize.width * Sizes.SettingsCardWidthFactor,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: Sizes.p43,
                          right: Sizes.p33,
                          top: Sizes.p28,
                        ),
                        child: ListView(children: const [
                          SettingsErrorHint(),
                          DefaultRelaySection(),
                          gapH25,
                          DashboardSection(),
                          gapH25,
                          AdvanceSection(),
                          gapH25,
                          LanguageSection(),
                        ]),
                      ),
                    ),
                  ],
                ),
                Text(strings.allRightsReserved)
              ],
            );
        }
      },
    );
  }
}
