import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/logging/logging.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_button.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OnboardingView extends StatefulWidget {
  final bool autoStart;
  
  const OnboardingView({super.key, this.autoStart = false});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final GlobalKey<OnboardingButtonState> _onboardingButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      // Auto-trigger the onboarding button after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onboardingButtonKey.currentState?.triggerOnboarding();
      });
    }
  }

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
              OnboardingButton(key: _onboardingButtonKey),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: Sizes.p44, right: 120),
            child: CustomTextButton.resetAtsign(),
          ),
        ),
        const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: Sizes.p44, right: 20),
            child: ExportLogsButton(),
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
