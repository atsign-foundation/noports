import 'dart:developer';

import 'package:at_app_flutter/at_app_flutter.dart';
import 'package:at_contacts_flutter/utils/init_contacts_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _pageIndex = 0;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    log('onboarding screen');
    // * load the AtClientPreference in the background
    Future<AtClientPreference> futurePreference = loadAtClientPreference();
    return false
        ? MacosWindow(
            sidebar: Sidebar(
                builder: ((context, scrollController) {
                  return SidebarItems(
                      items: const [
                        SidebarItem(
                          label: Text('home'),
                        ),
                        SidebarItem(
                          label: Text('terminal'),
                        ),
                        SidebarItem(
                          label: Text('settings'),
                        ),
                      ],
                      currentIndex: _pageIndex,
                      onChanged: (index) {
                        setState(() => _pageIndex = index);
                      });
                }),
                minWidth: 200),
            child: IndexedStack(
              index: _pageIndex,
              children: [
                ContentArea(builder: (((context, scrollController) {
                  return Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          AtOnboardingResult onboardingResult = await AtOnboarding.onboard(
                            context: context,
                            config: AtOnboardingConfig(
                              atClientPreference: await futurePreference,
                              rootEnvironment: AtEnv.rootEnvironment,
                              domain: AtEnv.rootDomain,
                              appAPIKey: AtEnv.appApiKey,
                            ),
                          );
                          switch (onboardingResult.status) {
                            case AtOnboardingResultStatus.success:
                              if (context.mounted) {
                                initializeContactsService(rootDomain: AtEnv.rootDomain);
                                context.goNamed(AppRoute.home.name);
                              }
                              break;
                            case AtOnboardingResultStatus.error:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text('An error has occurred'),
                                  ),
                                );
                              }
                              break;
                            case AtOnboardingResultStatus.cancel:
                              break;
                          }
                        },
                        child: const Text('Onboard an @sign'),
                      ),
                    ),
                  );
                })))
              ],
            ),
          )
        : Scaffold(
            appBar: AppBar(
              title: const Text('MyApp'),
            ),
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    AtOnboardingResult onboardingResult = await AtOnboarding.onboard(
                      context: context,
                      config: AtOnboardingConfig(
                        atClientPreference: await futurePreference,
                        rootEnvironment: AtEnv.rootEnvironment,
                        domain: AtEnv.rootDomain,
                        appAPIKey: AtEnv.appApiKey,
                      ),
                    );
                    switch (onboardingResult.status) {
                      case AtOnboardingResultStatus.success:
                        if (context.mounted) {
                          await initializeContactsService(rootDomain: AtEnv.rootDomain);
                          context.goNamed(AppRoute.home.name);
                        }
                        break;
                      case AtOnboardingResultStatus.error:
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.red,
                              content: Text('An error has occurred'),
                            ),
                          );
                        }
                        break;
                      case AtOnboardingResultStatus.cancel:
                        break;
                    }
                  },
                  child: const Text('Onboard an @sign'),
                ),
              ),
            ),
          );
  }
}

Future<AtClientPreference> loadAtClientPreference() async {
  var dir = await getApplicationSupportDirectory();

  return AtClientPreference()
    ..rootDomain = AtEnv.rootDomain
    ..namespace = AtEnv.appNamespace
    ..hiveStoragePath = dir.path
    ..commitLogPath = dir.path
    ..isLocalStoreRequired = true;
  // TODO
  // * By default, this configuration is suitable for most applications
  // * In advanced cases you may need to modify [AtClientPreference]
  // * Read more here: https://pub.dev/documentation/at_client/latest/at_client/AtClientPreference-class.html
}
