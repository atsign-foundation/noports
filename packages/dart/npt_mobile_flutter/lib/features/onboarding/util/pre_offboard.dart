import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/features.dart';

// Hand this method the atSign you wish to offboard
// Returns: a boolean, true = success, false = failed
Future<bool> preSignout() async {
  App.log("Resetting all application state before signout".loggable);
  final context = App.navState.currentContext;
  // We need to do the following before "signing out"
  // - Wipe all application state
  context?.read<ProfilesRunningCubit>().stopAllAndClear();
  context?.read<ProfileCacheCubit>().clear();
  context?.read<ProfilesSelectedCubit>().deselectAll();
  context?.read<FavoriteBloc>().clearAll();
  context?.read<ProfileListBloc>().clearAll();
  context?.read<SettingsBloc>().clear();
  context?.read<OnboardingCubit>().setStatus(OnboardingStatus.offboarded);
  // - Reset the tray icon (desktop-only)
  // context?.read<TrayCubit>().initialize();
  // Cleanup services before offboarding
  // Note: AuthorisationService is desktop-only and not available on mobile

  return true;
}
