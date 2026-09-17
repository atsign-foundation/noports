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

class ActivationDialogFinal extends StatelessWidget {
  /// A dialog which shows and activate each atsign in the activation file one by one, showing the activation status of each atsign, and allowing the user to sign in with the first activated Atsign once the activation process is complete.
  const ActivationDialogFinal({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    // final width = MediaQuery.of(context).size.width * 0.70;
    return BlocBuilder<MultiActivationCubit, MultiActivationState>(
      builder: (context, state) {
        final cubit = context.read<MultiActivationCubit>();
        final bool isComplete = cubit.isActivationComplete();
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
                  Text(
                    strings.activationStatus,
                    style: textTheme.headlineSmall!.copyWith(
                      color: AppColor.onSurfaceColorAlt,
                    ),
                  ),
                  gapW4,
                  Text(
                    cubit.getActivatingAtsign() ?? '',
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
                    '${state.fileContent.entries.where((entry) => entry.activationKeyStatus == ActivationKeyStatus.activated || entry.activationKeyStatus == ActivationKeyStatus.alreadyActivated).length}',
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

                            Tooltip(
                              // The status word alone doesn't tell a tester
                              // why an atsign failed, so hang the reason off it.
                              message: entry.failureReason ?? '',
                              child: Text(
                                entry.activationKeyStatus.name,
                                style: TextStyle(
                                  color:
                                      entry.activationKeyStatus ==
                                              ActivationKeyStatus.activated ||
                                          entry.activationKeyStatus ==
                                              ActivationKeyStatus
                                                  .alreadyActivated
                                      ? AppColor.primaryColor
                                      : entry.activationKeyStatus ==
                                            ActivationKeyStatus.failed
                                      ? AppColor.errorColor
                                      : AppColor.onSurfaceColorAlt,
                                ),
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

          // Every action stays hidden until activation has finished. Offering
          // sign in (or a second retry) while atsigns are still onboarding is
          // what left testers holding two sets of keys for the same atsign.
          actions: !isComplete
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: Sizes.p10),
                    child: Text(
                      strings.activationInProgress,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ]
              : [
                  if (cubit.isAnyFailedStatus())
                    ElevatedButton.icon(
                      onPressed: () {
                        cubit.reset();
                        Navigator.pop(context);
                      },
                      label: Text(strings.cancel),
                      icon: PhosphorIcon(PhosphorIcons.xCircle()),
                    ),
                  if (cubit.isAnyFailedStatus())
                    ElevatedButton.icon(
                      onPressed: () {
                        cubit.retryFailed();
                      },
                      label: Text(strings.activationRetryFailed),
                      icon: PhosphorIcon(PhosphorIcons.repeat()),
                    ),
                  if (cubit.getSignInAtsign() != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        // TODO: Refactor this method when migrating to at_client_flutter. Logic should be in a cubit or util class that can be shared between single atsign activation and multi atsign activation flows.

                        context.read<OnboardingCubit>().setState(
                          // Sign in with the last atsign that actually
                          // activated - they all come from the same activation
                          // file, so any of them will do, but a failed one
                          // won't authenticate.
                          atsign: cubit.getSignInAtsign(),

                          // TODO: User the root dimain in atsign information.
                          rootDomain: "root.atsign.org",
                        );
                        final util = await NoPortsOnboardingUtil.create(
                          context,
                        );

                        final atsignInformation = App.navState.currentContext!
                            .read<OnboardingCubit>()
                            .state;
                        Navigator.of(App.navState.currentContext!).pop();
                        App.navState.currentContext!
                            .read<MultiActivationCubit>()
                            .reset();
                        await util.onboard(
                          atsign: atsignInformation.atsign!,
                          rootDomain: atsignInformation.rootDomain,
                          context: App.navState.currentContext!,
                        );
                      },
                      label: Text(strings.signIn),
                      icon: PhosphorIcon(PhosphorIcons.signIn()),
                    ),
                ],
        );
      },
    );
  }
}
