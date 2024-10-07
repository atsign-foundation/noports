import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/features.dart';

// Hand this method the atSign you wish to offboard
// Returns: a boolean, true = success, false = failed
Future<bool> preSignout(String atSign) async {
  App.log("Resetting all application state before signout".loggable);
  // We need to do the following before "signing out"
  // - Wipe all application state
  App.navState.currentContext?.read<ProfilesRunningCubit>().stopAllAndClear();
  App.navState.currentContext?.read<ProfileCacheCubit>().clear();
  App.navState.currentContext?.read<ProfilesSelectedCubit>().deselectAll();
  App.navState.currentContext?.read<FavoriteBloc>().clearAll();
  App.navState.currentContext?.read<ProfileListBloc>().clearAll();
  App.navState.currentContext?.read<SettingsBloc>().clear();
  App.navState.currentContext?.read<OnboardingCubit>().offboard();
  // - Reset the tray icon
  App.navState.currentContext?.read<TrayCubit>().initialize();
  return true;
}
