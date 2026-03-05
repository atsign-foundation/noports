import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A dialog which shows the and activate each atsign in the activation file
class ActivationDialogFinal extends StatelessWidget {
  const ActivationDialogFinal({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    context.read<MultiActivationCubit>().activateAll;
    // final width = MediaQuery.of(context).size.width * 0.70;
    return BlocBuilder<MultiActivationCubit, MultiActivationState>(
      builder: (context, state) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.p10),
          ),
          content: Column(
            spacing: Sizes.p10,
            mainAxisSize: MainAxisSize.min,
            children: [
              gapH13,
              Row(
                children: [
                  PhosphorIcon(PhosphorIcons.spinnerGap()),
                  gapW10,
                  Text(
                    strings.activating,
                    style: textTheme.headlineSmall!.copyWith(
                      color: AppColor.onSurfaceColorAlt,
                    ),
                  ),
                  gapW4,
                  Text(
                    context
                            .read<MultiActivationCubit>()
                            .getActivatingAtsign() ??
                        '',
                    style: textTheme.headlineSmall!.copyWith(
                      color: AppColor.primaryColor,
                    ),
                  ),
                ],
              ),
              gapH13,
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.activationStatusCount(
                    '${state.fileContent.entries.where((entry) => entry.activationKeyStatus == ActivationKeyStatus.activated).length}',
                    '${state.fileContent.entries.length}',
                  ),
                ),
              ),
              CustomContainer.background(
                width: double.infinity,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.70,
                  height:
                      MediaQuery.of(context).size.height *
                      0.15, // Adjust the height as needed

                  child: ListView.separated(
                    // shrinkWrap: true,
                    // physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final entry = state.fileContent.entries[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sizes.p10,
                          vertical: Sizes.p12,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(Sizes.p10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: '@',
                                style: textTheme.bodyMedium!.copyWith(
                                  color: AppColor.primaryColor,
                                ),
                                children: [
                                  TextSpan(
                                    text: entry.atsign.replaceFirst('@', ''),
                                    style: textTheme.bodyMedium!.copyWith(
                                      color: AppColor.onSurfaceColorAlt,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              entry.activationKeyStatus.name,
                              style: TextStyle(
                                color:
                                    entry.activationKeyStatus ==
                                            ActivationKeyStatus.activated ||
                                        entry.activationKeyStatus ==
                                            ActivationKeyStatus.alreadyActivated
                                    ? AppColor.primaryColor
                                    : entry.activationKeyStatus ==
                                          ActivationKeyStatus.failed
                                    ? AppColor.errorColor
                                    : AppColor.onSurfaceColorAlt,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => gapH8,
                    itemCount: state.fileContent.entries.length,
                  ),
                ),
              ),
            ],
          ),

          actions: [
            context.read<MultiActivationCubit>().isAnyFailedStatus()
                ? ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    label: const Text('Cancel'),
                    icon: PhosphorIcon(PhosphorIcons.xCircle()),
                  )
                : gap0,
            context.read<MultiActivationCubit>().isAnyFailedStatus()
                ? ElevatedButton.icon(
                    onPressed: () {
                      context.read<MultiActivationCubit>().activateAll();
                    },
                    label: const Text('Retry'),
                    icon: PhosphorIcon(PhosphorIcons.repeat()),
                  )
                : gap0,
            context.read<MultiActivationCubit>().isAnyActivatedStatus()
                ? ElevatedButton.icon(
                    onPressed: () async {
                      // TODO: Refactor this method when migrating to at_client_flutter. Logic should be in a cubit or util class that can be shared between single atsign activation and multi atsign activation flows.

                      context.read<OnboardingCubit>().setState(
                        // Onboard with the first atsign in the list since they should all be the same atsigns from the activation file. This is needed to set the root domain and atsign in the onboarding cubit state which is used in the onboarding process after this dialog.
                        atSign: state.fileContent.entries.first.atsign,

                        // TODO: User the root dimain in atsign information.
                        rootDomain: "root.atsign.org",
                      );
                      final util = await NoPortsOnboardingUtil.create(context);

                      final atsignInformation = App.navState.currentContext!
                          .read<OnboardingCubit>()
                          .state;
                      Navigator.of(App.navState.currentContext!).pop();
                      App.navState.currentContext!
                          .read<MultiActivationCubit>()
                          .reset();
                      await util.onboard(
                        atsign: atsignInformation.atSign,
                        rootDomain: atsignInformation.rootDomain,
                        context: App.navState.currentContext!,
                      );
                    },
                    label: const Text('Sign In'),
                    icon: PhosphorIcon(PhosphorIcons.signIn()),
                  )
                : gap0,
          ],
        );
      },
    );
  }
}
