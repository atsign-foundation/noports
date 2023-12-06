import 'package:flutter_test/flutter_test.dart';

import '../../../robots/home_screen_robot.dart';
import '../../../robots/mocks.dart';

void main() {
  testWidgets(
    'home screen loaded',
    (tester) async {
      final r = HomeScreenRobot(tester);
      await r.pumpHomeScreen();
      r.findCurrentConnectionWidget();
      r.findCurrentConnectionsDescriptionWidget();
      r.findHomeActionsWidget();
    },
  );
  testWidgets(
    'home screen loaded with circular progress indicator',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final r = HomeScreenRobot(tester);
      await r.pumpHomeScreen(mockConfigListController: mockConfigListController);
      r.findHomeCircularProgressIndictor();
    },
  );
  testWidgets(
    'home screen loaded with empty data',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final r = HomeScreenRobot(tester);
      await r.pumpHomeScreen(mockConfigListController: mockConfigListController);
      // debugDumpApp();
      // r.findHomeErrorText();
      r.findHomeCircularProgressIndictor();
      await tester.pump();
      r.findNoConfigurationFoundWidget();
      // r.findHomeProfileBar();
    },
  );
  testWidgets(
    'home screen loaded with data',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final r = HomeScreenRobot(tester);
      await r.pumpHomeScreen(mockConfigListController: mockConfigListController);
      // debugDumpApp();

      r.findHomeCircularProgressIndictor();
      mockConfigListController.add('test');
      await tester.pump();
      r.findHomeProfileBar();
    },
  );
  testWidgets(
    'home screen loaded with error',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final r = HomeScreenRobot(tester);
      await r.pumpHomeScreen(mockConfigListController: mockConfigListController);
      // debugDumpApp();

      r.findHomeCircularProgressIndictor();
      mockConfigListController.throwError();
      await tester.pump();
      r.findHomeErrorText();
    },
  );
}
