import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/features.dart';

Future<void> postOnboard(String atSign, String rootDomain) async {
  App.log("setting all application state after onboarding".loggable);
  final context = App.navState.currentContext;
  context?.read<OnboardingCubit>().setState(
    atSign: atSign,
    rootDomain: rootDomain,
    status: OnboardingStatus.onboarded,
  );
  // Start loading application data in the background as soon as we have an atClient
  context?.read<FavoriteBloc>().add(const FavoriteLoadEvent());
  context?.read<ProfileListBloc>().add(const ProfileListLoadEvent());
  context?.read<SettingsBloc>().add(const SettingsLoadEvent());
  // Initialize services after onboarding
  // Note: AuthorisationService is desktop-only and not available on mobile
  await context?.read<PolicyCubit>().loadRoles(strings);
}
