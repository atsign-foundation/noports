import 'package:at_client_flutter/at_client_flutter.dart';
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
        child: EnrollmentRequestList(
          // Ensure a unique key so the list is rebuilt when switching atsigns
          key: ValueKey('authorization_hub_$atsign'),
        ),
      ),
    );
  }
}
