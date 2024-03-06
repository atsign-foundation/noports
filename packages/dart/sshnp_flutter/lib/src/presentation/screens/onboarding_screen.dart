import 'package:at_app_flutter/at_app_flutter.dart';
import 'package:at_contacts_flutter/utils/init_contacts_service.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../repository/authentication_repository.dart';
import '../../utility/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    // * load the AtClientPreference in the background
    Future<AtClientPreference> futurePreference = loadAtClientPreference();
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Image.asset(
              'assets/images/onboarding_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: SvgPicture.asset(
              'assets/images/overlay.svg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Builder(
              builder: (context) => SizedBox(
                width: 367,
                height: 255,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Sizes.p12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.only(top: Sizes.p30, bottom: Sizes.p10, left: Sizes.p30, right: Sizes.p30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/images/app_logo.svg',
                          fit: BoxFit.cover,
                          height: Sizes.p38,
                        ),
                        Text(
                          strings.welcomeTo,
                          style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                        ),
                        Text(
                          strings.sshnpDesktopApp,
                          style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                        ),
                        Text(
                          strings.welcomeToDescription,
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black),
                        ),
                        gapH20,
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              backgroundColor: kPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Sizes.p20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: Sizes.p60, vertical: Sizes.p10),
                            ),
                            onPressed: () async {
                              AtOnboardingResult onboardingResult = await AtOnboarding.onboard(
                                context: context,
                                config: AtOnboardingConfig(
                                  atClientPreference: await futurePreference,
                                  rootEnvironment: AtEnv.rootEnvironment,
                                  domain: AtEnv.rootDomain,
                                  appAPIKey: AtEnv.appApiKey,
                                  theme: AtOnboardingTheme(
                                    primaryColor: kPrimaryColor,
                                  ),
                                ),
                              );

                              switch (onboardingResult.status) {
                                case AtOnboardingResultStatus.success:
                                  await initializeContactsService(rootDomain: AtEnv.rootDomain);
                                  if (context.mounted) {
                                    context.replaceNamed(AppRoute.home.name);
                                  }
                                  await AuthenticationRepository().setFirstRun(true);

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
                            child: Text(
                              strings.onboardButtonDescription,
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        gapH10,
                        Center(
                            child: TextButton(
                          onPressed: () async {
                            await AtOnboarding.reset(
                              context: context,
                              config: AtOnboardingConfig(
                                atClientPreference: await futurePreference,
                                rootEnvironment: AtEnv.rootEnvironment,
                                domain: AtEnv.rootDomain,
                                appAPIKey: AtEnv.appApiKey,
                              ),
                            );
                          },
                          child: Text(
                            'Reset',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(color: Colors.black, fontWeight: FontWeight.w700),
                          ),
                        ))
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
