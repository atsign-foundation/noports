import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

Future<void> postOnboard(Atsign atsign, String rootDomain) async {
  App.log("setting all application state after onboarding".loggable);
  final context = App.navState.currentContext;
  context?.read<OnboardingCubit>().setState(
    atsign: atsign,
    rootDomain: rootDomain,
    status: OnboardingStatus.onboarded,
  );
  // Start loading application data in the background as soon as we have an atClient
  context?.read<FavoriteBloc>().add(const FavoriteLoadEvent());
  context?.read<ProfileListBloc>().add(const ProfileListLoadEvent());
  context?.read<SettingsBloc>().add(const SettingsLoadEvent());
  await context?.read<PolicyCubit>().loadRoles(AppLocalizations.of(context)!);
}
