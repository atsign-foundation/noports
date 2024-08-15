import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/routes.dart';

export 'package:npt_flutter/features/logging/logging.dart';

class App extends StatelessWidget {
  static final GlobalKey<NavigatorState> navState = GlobalKey<NavigatorState>();

  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProfileRepository>(
          create: (_) => ProfileRepository(),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (_) => const SettingsRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<EnableLoggingCubit>(
            create: (_) => EnableLoggingCubit(),
          ),

          /// Logging provider must come before ALL [LoggingBloc] & [LoggingCubit] providers
          /// There MUST be a [LogsCubit] provider as an ancestor widget
          BlocProvider<LogsCubit>(
            create: (_) => LogsCubit(),
          ),

          /// - A list of all the uuids for profiles which have been found in persistence
          ///   - This list is ALL of the profiles which are loaded in the app for the onboarded atSign
          ///     Note that multiple client atSigns have not been considered as part of the current implementation
          BlocProvider<ProfileListBloc>(
            create: (ctx) => ProfileListBloc(ctx.read<ProfileRepository>()),
          ),

          /// [ProfilesSelectedCubit] reads from [ProfileListBloc], and must be under it
          /// - A list of the uuids for profiles which have been check selected in the UI
          BlocProvider<ProfilesSelectedCubit>(
            create: (_) => ProfilesSelectedCubit(),
          ),

          /// - A map of uuid: SocketConnector for running profiles (a cache of running connections)
          BlocProvider<ProfilesRunningCubit>(
            create: (_) => ProfilesRunningCubit(),
          ),

          /// Settings provider, not much else to say
          /// - If settings are not found, we automatically load some defaults
          ///   so it is possible that someone's settings get wiped if there is
          ///   an issue loading them
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

  static void log(Loggable loggable) {
    navState.currentContext?.read<LogsCubit>().log(loggable);
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
