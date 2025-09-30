import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/settings/widgets/advance_section.dart';
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
            return Padding(
              padding: const EdgeInsets.all(Sizes.p40),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomCard.settingsRail(
                      height: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          gapH10,
                          CustomTextButton.backUpYourKey(),
                          CustomTextButton.faq(),
                          CustomTextButton.email(),
                          CustomTextButton.discord(),
                          CustomTextButton.feedback(),
                          CustomTextButton.privacyPolicy(),

                          CustomTextButton.signOut(),

                          // const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CustomCard.settingsContent(
                        height: double.infinity,
                        width: deviceSize.width * Sizes.settingsCardWidthFactor,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: Sizes.p43,
                            right: Sizes.p33,
                            top: Sizes.p28,
                          ),
                          child: ListView(
                            children: const [
                              DefaultRelaySection(),
                              gapH25,
                              DashboardSection(),
                              gapH25,
                              AdvanceSection(),
                              gapH25,
                              LanguageSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
