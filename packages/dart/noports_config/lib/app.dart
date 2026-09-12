import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/pages/home_page.dart';
import 'package:noports_config/pages/nav_cubit.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:noports_config/styles/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => ConfigCubit(ConfigRepository())..load()),
        BlocProvider(create: (_) => ServiceCubit(ServiceManager.instance)..init()),
        BlocProvider(create: (_) => HealthCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NoPorts Configuration',
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomePage(),
      ),
    );
  }
}
