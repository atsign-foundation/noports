import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/logging/models/loggable.dart';
import 'package:npt_flutter/features/onboarding/cubit/at_directory_cubit.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_dialog.dart';
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
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<AtDirectoryCubit, LoggableString>(
        builder: (context, rootDomain) {
      return ElevatedButton.icon(
        onPressed: () async {
          final result = await selectOptions();

          if (result && context.mounted) onboard(rootDomain: rootDomain.string);
        },
        icon: PhosphorIcon(PhosphorIcons.arrowUpRight()),
        label: Text(
          strings.getStarted,
        ),
        iconAlignment: IconAlignment.end,
      );
    });
  }

  Future<void> onboard(
      {required String rootDomain, bool isFromInitState = false}) async {
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

  Future<bool> selectOptions() async {
    final results = await showDialog(
      context: context,
      builder: (BuildContext context) => const AtDirectoryDialog(),
    );
    return results ?? false;
  }
}
