import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/settings/settings.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/advance_section.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/default_relay_section.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/language_section.dart';
import 'package:npt_mobile_flutter/widgets/custom_card.dart';
import 'package:npt_mobile_flutter/widgets/custom_text_button.dart';
import 'package:npt_mobile_flutter/widgets/spinner.dart';

import '../../../styles/sizes.dart';
import '../widgets/dashboard_section.dart';

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
            return const Center(child: Spinner());
          case SettingsLoadedState():
            // Mobile-optimized layout: single column with sections
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Settings content
                const DefaultRelaySection(),
                gapH25,
                const DashboardSection(),
                gapH25,
                const AdvanceSection(),
                gapH25,
                const LanguageSection(),
                gapH25,

                // Quick actions as cards
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.key),
                        title: const Text('Backup Your Key'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.backUpYourKey() functionality
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('FAQ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.faq() functionality
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email Support'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.email() functionality
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('Discord'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.discord() functionality
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.feedback_outlined),
                        title: const Text('Feedback'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.feedback() functionality
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // CustomTextButton.privacyPolicy() functionality
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}
