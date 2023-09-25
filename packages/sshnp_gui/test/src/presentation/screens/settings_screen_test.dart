import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../utility/settings_screen_robot.dart';

void main() {
  testWidgets('Settings Screen widgets found', (widgetTester) async {
    final r = SettingsScreenRobot(widgetTester);
    await r.pumpSettingsScreen();
    r.findSettings();
    r.findSettingBackupKeyActionButton();
    r.findSettingsSwitchAtsignActionButton();
    r.findSettingsResetAppActionButton();
    r.findSettingsFaqActionButton();
    r.findSettingsContactAction();
    r.findSettingsPrivacyPolicyAction();
    debugDumpApp();
  });
}
