import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_mobile_flutter/features/back_up_key/repository/backup_key_repository.dart';
import 'package:npt_mobile_flutter/features/features.dart';
import 'package:npt_mobile_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/styles/app_theme.dart';
import 'package:npt_mobile_flutter/util/language.dart';

export 'package:npt_mobile_flutter/features/logging/logging.dart';

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
        RepositoryProvider<BackUpKeyRepository>(
          create: (_) => BackUpKeyRepository(),
        ),
        RepositoryProvider<RoleRepository>(create: (_) => RoleRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<EnableLoggingCubit>(create: (_) => EnableLoggingCubit()),

          /// Logging provider must come before ALL [LoggingBloc] & [LoggingCubit] providers
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),

          // A bloc which manages the atDirectory state
          BlocProvider<OnboardingCubit>(create: (_) => OnboardingCubit()),

          /// Settings provider
          BlocProvider<SettingsBloc>(
            create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>()),
          ),

          /// Profile list bloc
          BlocProvider<ProfileListBloc>(
            create: (ctx) => ProfileListBloc(ctx.read<ProfileRepository>()),
          ),

          /// Profile cache cubit
          BlocProvider<ProfileCacheCubit>(
            create: (ctx) => ProfileCacheCubit(ctx.read<ProfileRepository>()),
          ),

          /// Selected profiles cubit
          BlocProvider<ProfilesSelectedCubit>(
            create: (_) => ProfilesSelectedCubit(),
          ),

          /// Running profiles cubit
          BlocProvider<ProfilesRunningCubit>(
            create: (_) => ProfilesRunningCubit(),
          ),

          /// Favorites bloc
          BlocProvider<FavoriteBloc>(
            create: (ctx) => FavoriteBloc(ctx.read<FavoriteRepository>()),
          ),

          /// Sync cubit
          BlocProvider<SyncCubit>(create: (_) => SyncCubit()),

          /// Backup key cubit
          BlocProvider<BackupKeyCubit>(create: (ctx) => BackupKeyCubit()),

          /// Policy cubit
          BlocProvider<PolicyCubit>(
            create: (ctx) => PolicyCubit(ctx.read<RoleRepository>()),
          ),
        ],
        child: BlocSelector<SettingsBloc, SettingsState, Language?>(
          selector: (state) {
            if (state is SettingsLoadedState) {
              return state.settings.language;
            }
            return null;
          },
          builder: (context, language) {
            Locale locale =
                language?.locale ??
                LanguageUtil.getLanguageFromLocale(
                  Locale(Platform.localeName),
                ).locale;
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              key: const Key("MaterialApp"),
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              localeResolutionCallback: (locale, supportedLocales) {
                return language != null ? language.locale : locale;
              },
              navigatorKey: navState,
              initialRoute: Routes.onboarding,
              routes: Routes.routes,
            );
          },
        ),
      ),
    );
  }
}
