import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:path_provider/path_provider.dart';

Future<AtClientPreference> loadAtClientPreference() async {
  var dir = await getApplicationSupportDirectory();

  return AtClientPreference()
    ..rootDomain = Constants.rootDomain
    ..namespace = Constants.namespace
    ..hiveStoragePath = dir.path
    ..commitLogPath = dir.path
    ..isLocalStoreRequired = true;
}

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({super.key, required this.nextRoute});
  final String nextRoute;

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<OnboardingButton> {
  final Future<AtClientPreference> futurePreference = loadAtClientPreference();

  @override
  void initState() {
    super.initState();
    onboard(isFromInitState: true);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onboard,
      child: const Text('Login'),
    );
  }

  Future<void> onboard({bool isFromInitState = false}) async {
    AtOnboardingResult onboardingResult = await AtOnboarding.onboard(
      // ignore: use_build_context_synchronously
      context: context,
      config: AtOnboardingConfig(
        atClientPreference: await futurePreference,
        rootEnvironment: RootEnvironment.Testing,
        domain: Constants.rootDomain,
        appAPIKey: Constants.appAPIKey,
      ),
    );

    if (mounted) {
      switch (onboardingResult.status) {
        case AtOnboardingResultStatus.success:
          await initializeContactsService(rootDomain: Constants.rootDomain);
          postOnboard(onboardingResult.atsign!);
          Navigator.of(context).pushReplacementNamed(widget.nextRoute);
          break;
        case AtOnboardingResultStatus.error:
          if (isFromInitState) break;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('An error has occurred'),
            ),
          );
          break;
        case AtOnboardingResultStatus.cancel:
          break;
      }
    }
  }
}
