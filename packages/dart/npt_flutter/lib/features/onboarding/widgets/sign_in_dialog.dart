import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

class SignInDialog extends StatefulWidget {
  const SignInDialog({required this.options, super.key});
  final Map<String, AtsignInformation> options;

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  bool visibility = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.signIn,
                style: titleStyle!.copyWith(color: Colors.black),
              ),
              CustomContainer.background(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.selectorTitleAtsign,
                      style: titleStyle.copyWith(color: Colors.black),
                    ),
                    Text(strings.selectorSubTitleAtsign),
                    gapH16,
                    AtsignSelector(options: widget.options),
                  ],
                ),
              ),

              CustomContainer.background(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.selectorTitleRootDomain,
                      style: titleStyle.copyWith(color: Colors.black),
                    ),
                    Text(strings.selectorSubTitleRootDomain),
                    gapH16,
                    AtDirectorySelector(options: widget.options),
                  ],
                ),
              ),
              const Divider(color: AppColor.dividerColor),
              BlocBuilder<OnboardingCubit, OnboardingState>(
                builder: (context, state) {
                  return SizedBox(
                    width: width,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: Text(strings.cancel),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(Sizes.p80, Sizes.p40),
                          ),
                          onPressed:
                              FormValidator.validateRequiredAtsignField(
                                    state.atSign,
                                  ) ==
                                  null
                              ? () {
                                  Navigator.of(context).pop(true);
                                }
                              : null,
                          child: Text(strings.onboard),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
