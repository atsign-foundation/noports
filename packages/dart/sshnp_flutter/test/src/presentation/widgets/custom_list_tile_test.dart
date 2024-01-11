import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_list_tile.dart';

import '../../../robots/custom_list_tile_robot.dart';

void main() {
  testWidgets(
    'Email Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.email(),
      );
      r.findEmailListTile();
    },
  );

  testWidgets(
    'Discord Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.discord(),
      );
      r.findDiscordListTile();
    },
  );

  testWidgets(
    'FAQ Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.faq(),
      );
      r.findFAQListTile();
    },
  );

  testWidgets(
    'Privacy Policy Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.privacyPolicy(),
      );
      r.findPrivacyPolicyListTile();
    },
  );

  testWidgets(
    'SSH Key Management Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.keyManagement(),
      );
      r.findSSHKeyManagementListTile();
    },
  );

  testWidgets(
    'Switch Atsign Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.switchAtsign(),
      );
      r.findSwitchAtsignListTile();
    },
  );

  testWidgets(
    'Back Up Your Key Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.backUpYourKey(),
      );
      r.findBackUpYourKeyListTile();
    },
  );

  testWidgets(
    'Reset Atsign Custom List Tile loaded',
    (widgetTester) async {
      final r = CustomListTileRobot(widgetTester);
      await r.pumpCustomListTile(
        customListTile: const CustomListTile.resetAtsign(),
      );
      r.findResetAtsignListTile();
    },
  );
}
