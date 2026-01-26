import 'package:at_contacts_flutter/at_contacts_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/util/profile_progress_listener.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final strings = AppLocalizations.of(App.navState.currentContext!)!;

class OnboardingButton extends StatefulWidget {
  const OnboardingButton({super.key});

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

enum _OnboardingButtonStatus { ready, loading }

class _OnboardingButtonState extends State<OnboardingButton> {
  _OnboardingButtonStatus buttonStatus = _OnboardingButtonStatus.ready;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ElevatedButton.icon(
      onPressed: () async {
        switch (buttonStatus) {
          case _OnboardingButtonStatus.ready:
            try {
              setState(() {
                buttonStatus = _OnboardingButtonStatus.loading;
              });
              bool shouldOnboard = await selectAtsign();
              if (shouldOnboard && context.mounted) {
                var atsignInformation = context.read<OnboardingCubit>().state;
                onboard(
                  atsign: atsignInformation.atSign,
                  rootDomain: atsignInformation.rootDomain,
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  buttonStatus = _OnboardingButtonStatus.ready;
                });
              }
            }
          case _OnboardingButtonStatus.loading:
          // Do nothing
        }
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (buttonStatus) {
          _OnboardingButtonStatus.ready => PhosphorIcon(
            key: const Key('getStartedIcon'),
            PhosphorIcons.arrowUpRight(),
          ),
          _OnboardingButtonStatus.loading => const SizedBox(
            key: Key('loading state'),
            height: Sizes.p18,
            width: Sizes.p18,
            child: CircularProgressIndicator(strokeWidth: Sizes.p2),
          ),
        },
      ),
      label: Text(strings.getStarted),
      iconAlignment: IconAlignment.end,
    );
  }

  /// Returns true if the user completed the selection and wants to proceed with onboarding. Returns false if the user cancelled the selection.
  /// Displays the onboarding dialog for the user to select an atsign. If there are no atsigns available, the atsign field will be blank.
  /// If there is an atsign available, it will be pre-selected along with its associated root domain.
  Future<bool> selectAtsign() async {
    var options = await getAtsignEntries();
    if (!mounted) return false;

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

  Future<void> onboard({
    required String atsign,
    required String rootDomain,
    bool isFromInitState = false,
  }) async {
    var atSigns = await KeyChainManager.getInstance()
        .getAtSignListFromKeychain();
    var apiKey = await Constants.appAPIKey;
    var config = AtOnboardingConfig(
      atClientPreference: await AtClientMethods.loadAtClientPreference(
        rootDomain,
      ),
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
      appAPIKey: apiKey,
    );

    var util = NoPortsOnboardingUtil(config);
    AtOnboardingResult? onboardingResult;

    if (!mounted) return;

    if (atSigns.contains(atsign)) {
      onboardingResult = await AtOnboarding.onboard(
        atsign: atsign,
        context: context,
        config: util.config,
      );
    } else {
      // Use the shared util method with progress callback
      onboardingResult = await util.handleAtsignByStatus(
        context: context,
        atsign: atsign,
        onProgress: (status) {
          // Handle file upload progress states
          if (status is FilePickingInProgress ||
              status is ProcessingAesKeyInProgress) {
            setState(() {
              buttonStatus = _OnboardingButtonStatus.loading;
            });
          }
        },
      );
    }
    setState(() {
      buttonStatus = _OnboardingButtonStatus.ready;
    });
    if (!mounted) return;
    switch (onboardingResult?.status ?? AtOnboardingResultStatus.cancel) {
      case AtOnboardingResultStatus.success:
        await initializeContactsService(rootDomain: rootDomain);
        AtClientManager.getInstance().atClient.syncService.addProgressListener(
          ProfileProgressListener(),
        );
        AtClientManager.getInstance().atClient.syncService.sync();
        postOnboard(onboardingResult!.atsign!, rootDomain);
        final result = await saveAtsignInformation(
          AtsignInformation(
            atSign: onboardingResult.atsign!,
            rootDomain: rootDomain,
          ),
        );
        final backupKeyCubit = App.navState.currentContext!
            .read<BackupKeyCubit>();

        await backupKeyCubit.putBackupKeyStatus(
          await backupKeyCubit.getBackupKeyStatus(),
        );

        App.log('atsign result is:$result'.loggable);

        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushNamed(Routes.home);

        break;
      case AtOnboardingResultStatus.error:
        if (isFromInitState) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              onboardingResult?.message ??
                  AppLocalizations.of(context)!.onboardingError,
            ),
          ),
        );
        break;
      case AtOnboardingResultStatus.cancel:
        break;
    }
  }
}
