import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/features/onboarding/cubit/at_directory_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/app_theme.dart';
import 'package:npt_flutter/util/language.dart';

export 'package:npt_flutter/features/logging/logging.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final GlobalKey<NavigatorState> navState = GlobalKey<NavigatorState>();

  static void log(Loggable loggable) {
    navState.currentContext?.read<LogsCubit>().log(loggable);
  }

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
        RepositoryProvider<FavoriteRepository>(
          create: (_) => FavoriteRepository(),
        ),
      ],
      child: MultiBlocProvider(
          providers: [
            // TODO this should be called LocalSettingsCubit and move
            // Localization from the SettingsCubit to this
            BlocProvider<EnableLoggingCubit>(
              create: (_) => EnableLoggingCubit(),
            ),

            /// Logging provider must come before ALL [LoggingBloc] & [LoggingCubit] providers
            /// There MUST be a [LogsCubit] provider as an ancestor widget
            BlocProvider<LogsCubit>(
              create: (_) => LogsCubit(),
            ),

            /// A cubit which manages the onboarding status
            BlocProvider<OnboardingCubit>(
              create: (_) => OnboardingCubit(),
            ),

            // A bloc which manages the atDirectory state
            BlocProvider<AtDirectoryCubit>(
              create: (_) => AtDirectoryCubit(),
            ),

            /// Settings provider, not much else to say
            /// - If settings are not found, we automatically load some defaults
            ///   so it is possible that someone's settings get wiped if there is
            ///   an issue loading them
            BlocProvider<SettingsBloc>(
              create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>()),
            ),

            /// - A list of all the uuids for profiles which have been found in persistence
            ///   - This list is ALL of the profiles which are loaded in the app for the onboarded atSign
            ///     Note that multiple client atSigns have not been considered as part of the current implementation
            BlocProvider<ProfileListBloc>(
              create: (ctx) => ProfileListBloc(ctx.read<ProfileRepository>()),
            ),

            /// A cubit which caches [ProfileBloc] by uuid so they can be shared
            /// between the dashboard and the system tray
            BlocProvider<ProfileCacheCubit>(
              create: (ctx) => ProfileCacheCubit(ctx.read<ProfileRepository>()),
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

            /// A cubit which manages the system tray entries
            BlocProvider<TrayCubit>(
              create: (_) => TrayCubit(),
            ),

            /// A bloc which manages favorites
            BlocProvider<FavoriteBloc>(
              create: (ctx) => FavoriteBloc(ctx.read<FavoriteRepository>()),
            ),
          ],
          child: BlocSelector<SettingsBloc, SettingsState, Language?>(selector: (state) {
            if (state is SettingsLoadedState) {
              return state.settings.language;
            }

            return null;
          }, builder: (context, language) {
            Locale defaultLocal = Language.english.locale;
            if (language == null) {
              //check if the device language is supported or not use english as the default.
              final deviceLocal = Locale(Platform.localeName.split('_').first);
              defaultLocal = LanguageUtil.getLanguageFromLocale(deviceLocal).locale;
            }
            return TrayManager(
              child: MaterialApp(
                theme: AppTheme.light(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: defaultLocal,
                localeResolutionCallback: (locale, supportedLocales) {
                  return language != null ? language.locale : locale;
                },
                navigatorKey: navState,
                initialRoute: Routes.onboarding,
                routes: Routes.routes,
              ),
            );
          })),
    );
  }
}
