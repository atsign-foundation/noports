import 'package:flutter/material.dart';
import 'package:npt_flutter/widgets/onboarding_button.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.nextRoute});
  final String nextRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: OnboardingButton(nextRoute: nextRoute));
  }
}
