import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/screens/home_screen.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_screen_widgets/profile_bar/profile_bar.dart';

class HomeScreenRobot {
  HomeScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpHomeScreen({ConfigListController? mockConfigListController}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          if (mockConfigListController != null) configListController.overrideWith(() => mockConfigListController)
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        )));
  }

  void findAvaiableConnectionWidget() {
    final finder = find.text('Available Connections');
    expect(finder, findsOneWidget);
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
