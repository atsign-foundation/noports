import 'package:at_app_flutter/at_app_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:sshnp_gui/src/utils/app_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // * load the AtClientPreference in the background
    Future<AtClientPreference> futurePreference = loadAtClientPreference();
    return Scaffold(
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
