import 'dart:developer';

import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/screen/at_onboarding_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_flutter/routes.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Future<AtClientPreference> loadAtClientPreference(String rootDomain) async {
  var dir = await getApplicationSupportDirectory();

  return AtClientPreference()
    ..rootDomain = rootDomain
    ..namespace = Constants.namespace
    ..hiveStoragePath = dir.path
    ..commitLogPath = dir.path
    ..isLocalStoreRequired = true;
}

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({
    super.key,
  });

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<OnboardingButton> {
  Future<void> onboard({String? atsign, required String rootDomain, bool isFromInitState = false}) async {
    var atSigns = await KeyChainManager.getInstance().getAtSignListFromKeychain();
    var config = AtOnboardingConfig(
      atClientPreference: await loadAtClientPreference(rootDomain),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: Constants.appAPIKey,
    );

    AtOnboardingResult? onboardingResult;
    if (!atSigns.contains(atsign)) {
      // This is a hack.
      // Ideally it should be possible to skip the home screen in onboarding
      // and go straight to either of the following (based on current atSign status):
      // A) opening the file picker
      // B) activating the atSign
      // But unfortunately that code is SO coupled to the widget that it is really
      // not worth the effort to fix right now.
      //
      // Assumptions made in at_onboarding_flutter which have caused this problem:
      // if [atsign] is non-null the atSign already exists in the keychain
      // thus any atsign that isn't in the keychain isn't handled if explicitly passed...
      // this means there is no edge case handling for new or unactivated atSigns
      // nor for atSigns that are activated but not in the keychain...
      //
      // Given that we are working on new user flows, I'm not going to waste countless
      // hours for this tiny UX fix

      // TODO: fix localizations
      await AtOnboardingLocalizations.load(const Locale("en"));
      onboardingResult = await Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (BuildContext context) {
            return AtOnboardingHomeScreen(
              config: config,
              isFromIntroScreen: false,
            );
          },
        ),
      );
    } else {
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        // ignore: use_build_context_synchronously
        context: context,
        config: config,
      );
    }

    if (mounted) {
      switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
        case AtOnboardingResultStatus.success:
          await initializeContactsService(rootDomain: rootDomain);
          postOnboard(onboardingResult!.atsign!, rootDomain);
          final result =
              await saveAtsignInformation(AtsignInformation(atSign: onboardingResult.atsign!, rootDomain: rootDomain));
          log('atsign result is:$result');

          if (mounted) {
            Navigator.of(context).pushReplacementNamed(Routes.dashboard);
          }
          break;
        case AtOnboardingResultStatus.error:
          if (isFromInitState) break;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(AppLocalizations.of(context)!.onboardingError),
            ),
          );
          break;
        case AtOnboardingResultStatus.cancel:
          break;
      }
    }
  }

  Future<bool> selectAtsign() async {
    var options = await getAtsignEntries();
    if (mounted) {
      final cubit = context.read<OnboardingCubit>();
      String atsign = cubit.state.atSign;
      String? rootDomain = cubit.state.rootDomain;

      if (options.isEmpty) {
        atsign = "";
      } else if (atsign.isEmpty) {
        atsign = options.keys.first;
      }
      if (options.keys.contains(atsign)) {
        rootDomain = options[atsign]?.rootDomain;
      } else {
        rootDomain = Constants.getRootDomains(context).keys.first;
      }

      cubit.setState(atSign: atsign, rootDomain: rootDomain);
      final results = await showDialog(
        context: context,
        builder: (BuildContext context) => OnboardingDialog(options: options),
      );
      return results ?? false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<AtDirectoryCubit, AtsignInformation>(builder: (context, atsignInformation) {
      return ElevatedButton.icon(
        onPressed: () async {
          final isEmptyAtsignList = (await getAtsignEntries()).isNotEmpty;

          bool proceedToOnboard = false;
          if (isEmptyAtsignList) proceedToOnboard = await selectAtsign();

          if (proceedToOnboard) onboard(rootDomain: atsignInformation.rootDomain);
        },
        icon: PhosphorIcon(PhosphorIcons.arrowUpRight()),
        label: Text(
          strings.getStarted,
        ),
        iconAlignment: IconAlignment.end,
      );
    });
  }
}
