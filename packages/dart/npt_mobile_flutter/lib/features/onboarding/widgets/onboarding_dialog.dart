import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/onboarding/onboarding.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/at_directory_selector.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/client_atsign_description_widget.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/form_validator.dart';
import 'package:npt_mobile_flutter/widgets/custom_container.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({required this.options, super.key});
  final Map<String, AtsignInformation> options;

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  bool visibility = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth > 600 ? screenWidth * 0.70 : screenWidth * 0.85;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      contentPadding: const EdgeInsets.all(Sizes.p8),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Sizes.p16,
        vertical: Sizes.p24,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Sizes.p8),
            child: Column(
              spacing: Sizes.p8,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomContainer.background(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.selectorTitleAtsign,
                        style: titleStyle!.copyWith(color: Colors.black),
                      ),
                      Text(
                        strings.selectorSubTitleAtsign,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      gapH16,
                      AtsignSelector(options: widget.options),
                    ],
                  ),
                ),
                ClientAtsignDescriptionWidget(width: width),
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
                      Text(
                        strings.selectorSubTitleRootDomain,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      gapH16,
                      AtDirectorySelector(options: widget.options),
                    ],
                  ),
                ),
                BlocBuilder<OnboardingCubit, OnboardingState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: width,
                      child: CustomContainer.background(
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
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
