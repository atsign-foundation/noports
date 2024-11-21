import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/features.dart';

Future<void> postOnboard(String atSign, String rootDomain) async {
  App.navState.currentContext?.read<OnboardingCubit>().setState(
        atSign: atSign,
        rootDomain: rootDomain,
        status: OnboardingStatus.onboarded,
      );
  // Start loading application data in the background as soon as we have an atClient
  App.navState.currentContext?.read<ProfileListBloc>().add(const ProfileListLoadEvent());
  App.navState.currentContext?.read<SettingsBloc>().add(const SettingsLoadEvent());
  App.navState.currentContext?.read<FavoriteBloc>().add(const FavoriteLoadEvent());
}
