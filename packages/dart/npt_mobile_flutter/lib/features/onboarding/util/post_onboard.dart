import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/features.dart';

Future<void> postOnboard(String atSign, String rootDomain) async {
  App.log(
    "[PostOnboard] Setting all application state after onboarding for $atSign"
        .loggable,
  );
  final context = App.navState.currentContext;
  context?.read<OnboardingCubit>().setState(
    atSign: atSign,
    rootDomain: rootDomain,
    status: OnboardingStatus.onboarded,
  );
  // Start loading application data in the background as soon as we have an atClient
  App.log(
    "[PostOnboard] Triggering initial data loads (favorites, profiles, settings)"
        .loggable,
  );
  context?.read<FavoriteBloc>().add(const FavoriteLoadEvent());
  // Profile load will try remote secondary first if local keystore is empty (APKAM case)
  // ProfileProgressListener will reload after sync completes to ensure consistency
  context?.read<ProfileListBloc>().add(const ProfileListLoadEvent());
  context?.read<SettingsBloc>().add(const SettingsLoadEvent());
  // Initialize services after onboarding
  // Note: AuthorisationService is desktop-only and not available on mobile
  await context?.read<PolicyCubit>().loadRoles(strings);
}
