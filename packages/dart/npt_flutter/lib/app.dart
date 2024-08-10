import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/profile/profile.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/settings/settings.dart';

import 'profile_list/profile_list.dart';

class App extends StatelessWidget {
  static final GlobalKey<NavigatorState> navState = GlobalKey<NavigatorState>();

  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProfileListRepository>(
          create: (_) => const ProfileListRepository(),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (_) => const ProfileRepository(),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (_) => const SettingsRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfileListBloc>(
            create: (ctx) => ProfileListBloc(ctx.read<ProfileListRepository>()),
          ),
          BlocProvider<SettingsBloc>(
            create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>()),
          ),
        ],
        child: MaterialApp(
          navigatorKey: App.navState,
          initialRoute: Routes.onboarding,
          routes: Routes.routes,
        ),
      ),
    );
  }

  static Future<void> postOnboard() async {
    // Start loading application data in the background as soon as we have an atClient
    navState.currentContext
        ?.read<ProfileListBloc>()
        .add(const ProfileListLoadEvent());
    navState.currentContext
        ?.read<SettingsBloc>()
        .add(const SettingsLoadEvent());
  }
}
