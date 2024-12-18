import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_button.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned.fill(
          child: SvgPicture.asset(
            'assets/onboarding_bg.svg',
            fit: BoxFit.cover,
          ),
        ),
        Align(
          child: Column(
            children: [
              gapH108,
              Text(
                strings.onboardingTitle,
                style: textTheme.headlineLarge!.copyWith(
                  color: Colors.black,
                ),
              ),
              Text(strings.onboardingSubTitle, style: textTheme.headlineMedium),
              gapH20,
              const OnboardingButton(),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: Sizes.p44,
              right: Sizes.p44,
            ),
            child: CustomTextButton.resetAtsign(),
          ),
        )
      ],
    );
  }
}
