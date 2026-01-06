import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/view/onboarding_view.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we should auto-start the onboarding flow
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final autoStart = args?['autoStart'] as bool? ?? false;
    
    return Scaffold(body: OnboardingView(autoStart: autoStart));
  }
}
