import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/view/onboarding_view.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.nextRoute});
  final String nextRoute;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: NptAppBar(
        isNavigateBack: false,
        showSettings: false,
      ),
      body: OnboardingView(),
    );
  }
}
