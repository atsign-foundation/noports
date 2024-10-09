import 'dart:developer';

import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/onboarding/cubit/at_directory_cubit.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_dialog.dart';
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
  Future<void> onboard({required String rootDomain, bool isFromInitState = false}) async {
    AtOnboardingResult onboardingResult = await AtOnboarding.onboard(
      // ignore: use_build_context_synchronously
      context: context,
      config: AtOnboardingConfig(
        atClientPreference: await loadAtClientPreference(rootDomain),
        rootEnvironment: RootEnvironment.Testing,
        domain: rootDomain,
        appAPIKey: Constants.appAPIKey,
      ),
    );

    if (mounted) {
      switch (onboardingResult.status) {
        case AtOnboardingResultStatus.success:
          await initializeContactsService(rootDomain: rootDomain);
          postOnboard(onboardingResult.atsign!);
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
    final results = await showDialog(
      context: context,
      builder: (BuildContext context) => const AtSignDialog(),
    );
    return results ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<AtDirectoryCubit, AtsignInformation>(builder: (context, atsignInformation) {
      return ElevatedButton.icon(
        onPressed: () async {
          final isEmptyAtsignList = (await getAtsignEntries()).isNotEmpty;
          log('atsign entries is empty state: $isEmptyAtsignList');

          if (isEmptyAtsignList) await selectAtsign();

          onboard(rootDomain: atsignInformation.rootDomain);
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
