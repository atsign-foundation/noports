import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/screens/settings_screen.dart';
import 'package:sshnp_gui/src/presentation/widgets/settings_actions/settings_actions.dart';

class SettingsScreenRobot {
  SettingsScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpSettingsScreen({ConfigListController? mockConfigListController}) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ));
  }

  void findSettings() {
    final finder = find.text('Settings');
    expect(finder, findsOneWidget);
  }

  void findSettingBackupKeyActionButton() {
    final finder = find.byType(SettingsBackupKeyAction);

    expect(finder, findsOneWidget);
  }

  void findSettingsSwitchAtsignActionButton() {
    final finder = find.byType(SettingsSwitchAtsignActionMobile);
    expect(finder, findsWidgets);
  }

  void findSettingsResetAppActionButton() {
    final finder = find.byType(SettingsResetAppAction);
    expect(finder, findsOneWidget);
  }

  void findSettingsFaqActionButton() {
    final finder = find.byType(SettingsFaqAction);
    expect(finder, findsOneWidget);
  }

  void findSettingsContactAction() {
    final finder = find.byType(SettingsContactAction);
    expect(finder, findsOneWidget);
  }

  void findSettingsPrivacyPolicyAction() {
    final finder = find.byType(SettingsPrivacyPolicyAction);
    expect(finder, findsOneWidget);
  }
}
