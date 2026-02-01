import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/pre_offboard.dart';
import 'package:npt_mobile_flutter/features/settings/settings.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/advance_section.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/default_relay_section.dart';
import 'package:npt_mobile_flutter/features/settings/widgets/language_section.dart';
import 'package:npt_mobile_flutter/home_wrapper_widget.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/widgets/custom_card.dart';
import 'package:npt_mobile_flutter/widgets/custom_text_button.dart';
import 'package:npt_mobile_flutter/widgets/spinner.dart';
import 'package:npt_mobile_flutter/widgets/custom_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';

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
                          context.read<BackupKeyCubit>().backUpKeys(popDialog: false);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('FAQ'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final Uri url = Uri.parse('https://docs.noports.com/ssh-no-ports/faq');
                          if (!await launchUrl(url)) {
                            if (context.mounted) {
                              CustomSnackBar.notification(
                                content: 'Could not open FAQ',
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email Support'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Uri emailUri = Uri(scheme: 'mailto', path: 'info@noports.com');
                          if (!await launchUrl(emailUri)) {
                            if (context.mounted) {
                              final strings = AppLocalizations.of(context)!;
                              CustomSnackBar.notification(
                                content: strings.noEmailClientAvailable,
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('Discord'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final Uri url = Uri.parse('https://discord.gg/atsign-778383211214536722');
                          if (!await launchUrl(url)) {
                            if (context.mounted) {
                              CustomSnackBar.notification(
                                content: 'Could not open Discord',
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.feedback_outlined),
                        title: const Text('Feedback'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final emailUri = Uri(
                            scheme: 'mailto',
                            path: 'info@noports.com',
                            query: 'subject=No Ports Mobile Feedback',
                          );
                          if (!await launchUrl(emailUri)) {
                            if (context.mounted) {
                              final strings = AppLocalizations.of(context)!;
                              CustomSnackBar.notification(
                                content: strings.noEmailClientAvailable,
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final Uri url = Uri.parse('https://atsign.com/privacy-policy/');
                          if (!await launchUrl(url)) {
                            if (context.mounted) {
                              CustomSnackBar.notification(
                                content: 'Could not open Privacy Policy',
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                gapH25,
                
                // Sign out and account management
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout_outlined, color: Colors.orange),
                        title: const Text('Sign Out'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final strings = AppLocalizations.of(context)!;
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(strings.signout),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    // Perform sign out
                                    await preSignout();
                                    if (context.mounted) {
                                      Navigator.of(context, rootNavigator: true)
                                        .pushNamedAndRemoveUntil(
                                          Routes.onboarding, 
                                          (route) => false,
                                        );
                                    }
                                  },
                                  child: Text(strings.signout, style: const TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          );
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
