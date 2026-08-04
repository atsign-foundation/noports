import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/features.dart';

// Hand this method the atsign you wish to offboard
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
  // - Reset the tray icon
  context?.read<TrayCubit>().initialize();
  await context?.read<FlutterEnrollmentService>().dispose();

  return true;
}
