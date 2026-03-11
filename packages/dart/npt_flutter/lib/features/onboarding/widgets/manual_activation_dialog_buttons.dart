import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/widgets/get_started_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ManualActivationDialogButtons extends StatelessWidget {
  const ManualActivationDialogButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return SizedBox(
          width: width,
          child: Row(
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    animationStyle: AnimationStyle.noAnimation,
                    builder: (BuildContext context) => const GetStartedDialog(),
                  );
                },
                child: Text(strings.cancel),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    FormValidator.validateRequiredAtsignField(state.atSign) ==
                        null
                    ? () async {
                        Navigator.of(context).pop(true);
                        final util = await NoPortsOnboardingUtil.create(
                          context,
                        );
                        final atsignInformation = App.navState.currentContext!
                            .read<OnboardingCubit>()
                            .state;
                        await util.onboard(
                          atsign: atsignInformation.atSign,
                          rootDomain: atsignInformation.rootDomain,
                          context: App.navState.currentContext!,
                        );
                      }
                    : null,
                child: Text(strings.next),
              ),
            ],
          ),
        );
      },
    );
  }
}
