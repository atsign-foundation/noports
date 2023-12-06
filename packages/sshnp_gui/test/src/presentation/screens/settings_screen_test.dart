import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../robots/settings_screen_robot.dart';

void main() {
  testWidgets('Settings Screen widgets found', (widgetTester) async {
    final r = SettingsScreenRobot(widgetTester);
    await r.pumpSettingsScreen();
    r.findSettings();
    r.findAccount();
    r.findContactListTile();
    r.findSshKeyManagementListTile();
    r.findBackupYourKeysListTile();
    r.findSettingsSwitchAtsignListTile();
    r.findSettingsResetAppActionButton();
    debugDumpApp();
  });
}
