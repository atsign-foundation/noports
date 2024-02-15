import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/utility/app_theme.dart';
import 'package:sshnp_flutter/src/utility/platform_utility/platform_utility.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DefaultPlatformUtility implements PlatformUtility {
  const DefaultPlatformUtility();

  @override
  void configurePlatform() {}

  @override
  bool isPlatform() => true;

  @override
  Widget get app => const _MyApp();
}

class _MyApp extends ConsumerWidget {
  const _MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SSHNP',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(navigationController),
      theme: AppTheme.dark(),
      // * The onboarding screen (first screen)p[]
    );
  }
}
