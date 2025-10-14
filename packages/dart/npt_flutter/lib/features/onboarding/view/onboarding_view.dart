import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_button.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: Sizes.p44, left: Sizes.p44),
            child: SvgPicture.asset(
              'assets/noports_logo.svg',
              width: Sizes.p200,
            ),
          ),
        ),
        Align(
          child: Column(
            children: [
              gapH108,
              Text(
                strings.onboardingTitle,
                style: textTheme.headlineLarge!.copyWith(color: Colors.black),
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
            padding: EdgeInsets.only(bottom: Sizes.p44, right: Sizes.p44),
            child: CustomTextButton.resetAtsign(),
          ),
        ),
        FutureBuilder(
          future: PackageInfo.fromPlatform(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: Sizes.p44,
                    left: Sizes.p44,
                  ),
                  child: Text(
                    'v${snapshot.data?.version}',
                    style: textTheme.bodySmall,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
