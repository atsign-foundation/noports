import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/widgets/activation_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:super_tooltip/super_tooltip.dart';
import 'package:url_launcher/url_launcher.dart';

class GetStartedDialog extends StatefulWidget {
  const GetStartedDialog({super.key});

  @override
  State<GetStartedDialog> createState() => _GetStartedDialogState();
}

class _GetStartedDialogState extends State<GetStartedDialog> {
  bool visibility = false;

  void visitRegistarSite() async {
    final Uri url = Uri.parse('https://my.noports.com/no-ports-plans/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final toolTipController = SuperTooltipController();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.p20),
          child: Column(
            spacing: Sizes.p10,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                strings.getStarted,
                style: titleStyle!.copyWith(color: Colors.black),
              ),
              gapH16,

              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  final results = await showDialog(
                    context: context,
                    builder: (BuildContext context) => const ActivationDialog(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(Sizes.p440, Sizes.p50),
                  backgroundColor: AppColor.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(strings.activate),
              ),
              Text(
                strings.activateButtonDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Divider(
                      color: AppColor.dividerColor,
                      height: Sizes.p1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.p8),
                    child: Text(strings.or),
                  ),
                  const Expanded(
                    child: Divider(
                      color: AppColor.dividerColor,
                      height: Sizes.p1,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  final util = await NoPortsOnboardingUtil.create(context);

                  bool shouldOnboard = await util.selectAtsign(context);
                  if (shouldOnboard) {
                    final atsignInformation = App.navState.currentContext!
                        .read<OnboardingCubit>()
                        .state;
                    util.onboard(
                      atsign: atsignInformation.atSign,
                      rootDomain: atsignInformation.rootDomain,
                      context: App.navState.currentContext!,
                    );
                  }
                  print("should onbaord is $shouldOnboard");
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(Sizes.p440, Sizes.p50),
                  side: const BorderSide(color: AppColor.primaryColor),
                ),
                child: Text(strings.signIn),
              ),
              Text(
                strings.signInButtonDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              GestureDetector(
                onTap: () => toolTipController.showTooltip(),
                child: SuperTooltip(
                  popupDirection: TooltipDirection.right,
                  controller: toolTipController,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(strings.whatIsAnAtsignDescription),
                      TextButton(
                        onPressed: visitRegistarSite,
                        child: Text(
                          strings.myNoPortsMsg,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: AppColor.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: Sizes.p6,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColor.primaryColor,
                        size: Sizes.p16,
                      ),

                      Text(
                        strings.whatIsAnAtsign,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppColor.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
