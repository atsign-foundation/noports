import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/screens/home_screen.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_widgets/home_screen_actions/import_profile_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_widgets/home_screen_actions/new_profile_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_bar/profile_bar.dart';
import 'package:sshnp_gui/src/utility/app_theme.dart';

class HomeScreenRobot {
  HomeScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpHomeScreen({ConfigListController? mockConfigListController}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          if (mockConfigListController != null) configListController.overrideWith(() => mockConfigListController)
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
          theme: AppTheme.dark(),
        )));
  }

  void findCurrentConnectionWidget() {
    final finder = find.text('Current Connections');
    expect(finder, findsOneWidget);
  }

  void findCurrentConnectionsDescriptionWidget() {
    final finder = find.text('Toggle, configure and create connection profiles');
    expect(finder, findsOneWidget);
  }

  void findHomeActionsWidget() {
    final importProfileFinder = find.byType(ImportProfileAction);
    final newProfileFinder = find.byType(NewProfileAction);
    expect(importProfileFinder, findsOneWidget);
    expect(newProfileFinder, findsOneWidget);
  }

  void findHomeCircularProgressIndictor() {
    final finder = find.byType(CircularProgressIndicator);

    expect(finder, findsOneWidget);
  }

  void findHomeProfileBar() {
    final finder = find.byType(ProfileBar);
    expect(finder, findsWidgets);
  }

  void findHomeErrorText() {
    final finder = find.textContaining('Error');
    expect(finder, findsOneWidget);
  }

  void findNoConfigurationFoundWidget() {
    final finder = find.text('No SSHNP Configurations Found');
    expect(finder, findsOneWidget);
  }

  void findHomeScreenActionsWidget() {
    final finder = find.text('Available Connections');
    expect(finder, findsOneWidget);
  }
}
