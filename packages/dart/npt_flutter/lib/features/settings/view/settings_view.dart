import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/settings/widgets/advance_section.dart';
import 'package:npt_flutter/features/settings/widgets/default_relay_section.dart';
import 'package:npt_flutter/features/settings/widgets/language_section.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:npt_flutter/widgets/switch_atsign_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../styles/sizes.dart';
import '../widgets/dashboard_section.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
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
                      height: deviceSize.height * Sizes.settingsCardHeightFactor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          gapH10,
                          const SwitchAtsignButton(),
                          const CustomTextButton.backUpYourKey(),
                          const CustomTextButton.faq(),
                          const CustomTextButton.email(),
                          const CustomTextButton.discord(),
                          const CustomTextButton.feedback(),
                          const CustomTextButton.privacyPolicy(),
                          // const CustomTextButton.switchAtsign(),
                          const CustomTextButton.signOut(),
                          gapH13,
                          FutureBuilder(
                              future: PackageInfo.fromPlatform(),
                              builder: (_, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done) {
                                  return Center(
                                    child: Text(
                                      'v${snapshot.data?.version}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                          gapH10,
                        ],
                      ),
                    ),
                    CustomCard.settingsContent(
                      height: deviceSize.height * Sizes.settingsCardHeightFactor,
                      width: deviceSize.width * Sizes.settingsCardWidthFactor,
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
              ],
            );
        }
      },
    );
  }
}
