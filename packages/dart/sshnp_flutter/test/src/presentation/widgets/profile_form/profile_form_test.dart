import 'package:flutter_test/flutter_test.dart';
import 'package:noports_core/sshnp.dart';

import '../../../../robots/mocks.dart';
import '../../../../robots/profile_form_robot.dart';

void main() {
  testWidgets(
    'Profile Form loaded with circular progress indicator',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final mockConfigFamilyController = MockConfigFamilyController();
      final r = ProfileFormRobot(tester);
      await r.pumpProfileForm(
          mockConfigListController: mockConfigListController, mockConfigFamilyController: mockConfigFamilyController);
      r.findCircularProgressIndicator();

      // r.findHomeErrorText();
      // r.findNoConfigurationFoundWidget();
      // await tester.pump();
      // r.findHomeProfileBar();
    },
  );
  testWidgets(
    'Profile Form widget has default config values',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final mockConfigFamilyController = MockConfigFamilyController();
      final r = ProfileFormRobot(tester);
      await r.pumpProfileForm(
          mockConfigListController: mockConfigListController, mockConfigFamilyController: mockConfigFamilyController);
      r.findCircularProgressIndicator();
      await tester.pump();
      final configFile = SshnpParams.empty();
      r.findProfileFormWidgetsWithDefaultValues(configFile: configFile);
    },
  );
  testWidgets(
    'Profile Form fields are populated With values',
    (tester) async {
      final mockConfigListController = MockConfigListController();
      final mockConfigFamilyController = MockConfigFamilyController();
      final r = ProfileFormRobot(tester);
      await r.pumpProfileForm(
          mockConfigListController: mockConfigListController, mockConfigFamilyController: mockConfigFamilyController);
      r.findCircularProgressIndicator();
      await tester.pump();

      r.findProfileFormWidgetsWithNewValues();
    },
  );
  // testWidgets(
  //   'Profile Form Submitted With values',
  //   (tester) async {
  //     final mockConfigListController = MockConfigListController();
  //     final mockConfigFamilyController = MockConfigFamilyController();
  //     final r = ProfileFormRobot(tester);
  //     await r.pumpProfileForm(
  //         mockConfigListController: mockConfigListController, mockConfigFamilyController: mockConfigFamilyController);
  //     debugDumpApp();
  //     r.findCircularProgressIndictor();
  //     await tester.pump();

  //     r.submitFormWithValues();
  //   },
  // );
}
