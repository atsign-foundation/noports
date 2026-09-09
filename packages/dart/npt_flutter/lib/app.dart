import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/back_up_key/repository/backup_key_repository.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
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
        RepositoryProvider<ProfileGroupRepository>(
          create: (_) => ProfileGroupRepository(),
        ),
        RepositoryProvider<BackUpKeyRepository>(
          create: (_) => BackUpKeyRepository(),
        ),
        RepositoryProvider<RoleRepository>(create: (_) => RoleRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          // TODO this should be called LocalSettingsCubit and move
          // Localization from the SettingsCubit to this
          BlocProvider<EnableLoggingCubit>(create: (_) => EnableLoggingCubit()),

          /// Logging provider must come before ALL [LoggingBloc] & [LoggingCubit] providers
          /// There MUST be a [LogsCubit] provider as an ancestor widget
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),

          // A bloc which manages the atDirectory state
          BlocProvider<OnboardingCubit>(create: (_) => OnboardingCubit()),

          /// Tracks which top level tab of the home navigator is selected.
          /// Lives above [HomeWrapperWidget] so the selected tab survives the
          /// wrapper being rebuilt (e.g. when adding / switching atsign).
          BlocProvider<SubNavCubit>(create: (_) => SubNavCubit()),

          /// Settings provider, not much else to say
          /// - If settings are not found, we automatically load some defaults
          ///   so it is possible that someone's settings get wiped if there is
          ///   an issue loading them
          BlocProvider<SettingsBloc>(
            create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>()),
          ),

          /// - A list of all the uuids for profiles which have been found in persistence
          ///   - This list is ALL of the profiles which are loaded in the app for the onboarded atsign
          ///     Note that multiple client atsigns have not been considered as part of the current implementation
          BlocProvider<ProfileListBloc>(
            create: (ctx) => ProfileListBloc(ctx.read<ProfileRepository>()),
          ),

          /// Custom folders and the "group by type" preference for the
          /// connections list, persisted as a single blob on the atServer
          BlocProvider<ProfileGroupBloc>(
            create: (ctx) =>
                ProfileGroupBloc(ctx.read<ProfileGroupRepository>()),
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
          BlocProvider<TrayCubit>(create: (_) => TrayCubit()),

          /// A bloc which manages favorites
          BlocProvider<FavoriteBloc>(
            create: (ctx) => FavoriteBloc(ctx.read<FavoriteRepository>()),
          ),
          BlocProvider<PendingRequestsCountCubit>(
            create: (ctx) => PendingRequestsCountCubit(),
          ),

          /// A cubit which tracks the sync status of the profiles
          BlocProvider<SyncCubit>(create: (_) => SyncCubit()),
          // A cubit which tracks if the atkey is backed up
          BlocProvider<BackupKeyCubit>(create: (ctx) => BackupKeyCubit()),
          BlocProvider<PolicyCubit>(
            create: (ctx) => PolicyCubit(ctx.read<RoleRepository>()),
          ),
          //
          BlocProvider<MultiActivationCubit>(
            create: (ctx) => MultiActivationCubit(),
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
            return TrayManager(
              locale: locale,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                key: const Key("MaterialApp"),
                theme: AppTheme.light(),
                localizationsDelegates: const [
                  ...AppLocalizations.localizationsDelegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                locale: locale,
                localeResolutionCallback: (locale, supportedLocales) {
                  return language != null ? language.locale : locale;
                },
                navigatorKey: navState,
                initialRoute: Routes.onboarding,
                routes: Routes.routes,
              ),
            );
          },
        ),
      ),
    );
  }
}
