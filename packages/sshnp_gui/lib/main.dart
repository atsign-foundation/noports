import 'dart:async';

import 'package:at_app_flutter/at_app_flutter.dart' show AtEnv;
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/theme.dart';
import 'package:sshnp_gui/src/utils/util.dart';

final AtSignLogger _logger = AtSignLogger(AtEnv.appNamespace);

Future<void> main() async {
  // * AtEnv is an abtraction of the flutter_dotenv package used to
  // * load the environment variables set by at_app
  try {
    await AtEnv.load();
  } catch (e) {
    _logger.finer('Environment failed to load from .env: ', e);
  }

  /// This method initializes macos_window_utils and styles the window.
  Future<void> _configureMacosWindowUtils() async {
    const config = MacosWindowUtilsConfig(toolbarStyle: NSWindowToolbarStyle.unified);
    await config.apply();
  }

  if (Util.isMacos()) {
    // await _configureMacosWindowUtils();

    runApp(const ProviderScope(child: MyApp()));
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SSHNP',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(goRouterProvider),
      theme: AppTheme.dark(),
      // * The onboarding screen (first screen)p[]
    );
  }
}

class MyMacApp extends ConsumerWidget {
  const MyMacApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MacosApp.router(
      title: 'SSHNP',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(goRouterProvider),
      theme: AppTheme.macosDark(),
      darkTheme: AppTheme.macosDark(),
      themeMode: ThemeMode.dark,
      // * The onboarding screen (first screen)p[]
    );
  }
}
