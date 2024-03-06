import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/utility/app_theme.dart';
import 'package:sshnp_flutter/src/utility/platform_utility/default_platform_utility.dart';
import 'package:sshnp_flutter/src/utility/platform_utility/platform_utility.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MacosUtility implements PlatformUtility {
  const MacosUtility();

  @override
  Future<void> configurePlatform() async {
    return;
  }

  @override
  bool isPlatform() {
    return Platform.isMacOS && !kIsWeb;
  }

  @override
  Widget get app => const DefaultPlatformUtility().app; //const _MyApp();
}

class _MyApp extends ConsumerWidget {
  const _MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MacosApp.router(
      title: 'SSHNP',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(navigationController),
      theme: AppTheme.macosDark(),
      darkTheme: AppTheme.macosDark(),
      themeMode: ThemeMode.dark,
      // * The onboarding screen (first screen)p[]
    );
  }
}
