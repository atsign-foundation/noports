import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/onboarding/widgets/file_based_activation.dart';
import 'package:npt_flutter/features/onboarding/widgets/manual_activation.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/widgets/or_divider.dart';

class ActivationDialog extends StatefulWidget {
  const ActivationDialog({super.key});

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  bool visibility = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;

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
            children: [
              const FileBasedActivation(),
              const OrDivider(),
              const ManualActivation(),
              const Divider(color: AppColor.dividerColorAlt),
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
                          onPressed:
                              FormValidator.validateRequiredAtsignField(
                                    state.atSign,
                                  ) ==
                                  null
                              ? () {
                                  Navigator.of(context).pop(true);
                                }
                              : null,
                          child: Text(strings.next),
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
