import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';

class AuthorisationView extends StatelessWidget {
  const AuthorisationView({super.key});
  @override
  Widget build(BuildContext context) {
    final atSign = context.watch<OnboardingCubit>().getAtSign();
    return Padding(
      padding: const EdgeInsets.all(64.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AuthorisationHub(
          // Ensure a unique key so that the AuthorisationHub is rebuilt when switching atsigns
          key: ValueKey('authorization_hub_$atSign'),
          service: context.watch<AuthorisationService>(),
          themeData: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
