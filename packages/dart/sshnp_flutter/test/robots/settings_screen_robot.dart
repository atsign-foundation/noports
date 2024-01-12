import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/presentation/screens/settings_screen.dart';
import 'package:sshnp_flutter/src/presentation/widgets/contact_tile/contact_list_tile.dart';
import 'package:sshnp_flutter/src/presentation/widgets/custom_list_tile.dart';
import 'package:sshnp_flutter/src/utility/app_theme.dart';

class SettingsScreenRobot {
  SettingsScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpSettingsScreen(
      {ConfigListController? mockConfigListController}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: const [],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark(),
        home: const SettingsScreen(),
      ),
    ));
  }

  void findSettings() {
    final finder = find.text('Settings');
    expect(finder, findsOneWidget);
  }

  void findAccount() {
    final finder = find.text('Account');
    expect(finder, findsOneWidget);
  }

  void findContactListTile() {
    final finder = find.byType(ContactListTile);
    expect(finder, findsOneWidget);
  }

  void findSshKeyManagementListTile() {
    final finder = find.widgetWithText(CustomListTile, 'SSH Key Management');
    expect(finder, findsOneWidget);
  }

  void findBackupYourKeysListTile() {
    final finder = find.widgetWithText(CustomListTile, 'Backup Your Keys');
    expect(finder, findsOneWidget);
  }

  void findSettingsSwitchAtsignListTile() {
    final finder = find.widgetWithText(CustomListTile, 'Switch atsign');
    expect(finder, findsOneWidget);
  }

  void findSettingsResetAppActionButton() {
    final finder = find.widgetWithText(CustomListTile, 'Reset App');
    expect(finder, findsOneWidget);
  }
}
