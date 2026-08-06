import 'package:at_client/at_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';

class AuthorisationView extends StatelessWidget {
  const AuthorisationView({super.key});
  @override
  Widget build(BuildContext context) {
    final atsign = context.watch<OnboardingCubit>().getAtsign();
    return Padding(
      padding: const EdgeInsets.all(64.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AuthorisationHub(
          // Ensure a unique key so that the AuthorisationHub is rebuilt when switching atsigns
          key: ValueKey('authorization_hub_$atsign'),
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
