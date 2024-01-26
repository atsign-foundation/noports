import 'package:flutter_test/flutter_test.dart';

import '../../../../robots/support_screen_robot.dart';

void main() {
  testWidgets(
    'support_screen_desktop_view_test',
    (widgetTester) async {
      final r = SupportScreenRobot(widgetTester);
      await r.pumpSupportScreen();
      r.findSupport();
      r.findSupportDescription();
      r.findDiscordListTile();
      r.findEmailListTile();
      r.findFAQListTile();
      r.findPrivacyPolicyListTile();
    },
  );
}
