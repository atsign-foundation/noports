import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/main.dart' as app;
import 'package:npt_flutter/widgets/custom_text_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow Integration Tests', () {
    testWidgets('App launches and displays all onboarding UI elements correctly', (WidgetTester tester) async {
      // Load the app
      app.main();
      await tester.pumpAndSettle();

      // Verify core onboarding UI elements
      expect(find.byType(OnboardingButton), findsOneWidget);
      expect(find.widgetWithText(CustomTextButton, 'Reset atSign'), findsOneWidget);

      // Verify app structure and version display
      expect(find.byType(Navigator), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('v'), findsOneWidget);

      // Verify no rendering exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Get Started button interaction and dialog flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      tester.printToConsole('App launched and onboarding UI is displayed');

      final getStartedButton = find.byType(OnboardingButton);
      expect(getStartedButton, findsOneWidget);

      // Test button loading state
      await tester.tap(getStartedButton);
      await tester.pump(); // Just one pump to see immediate loading state

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('loading state')), findsOneWidget);
      tester.printToConsole('Loading state is shown');

      // Wait for dialog to appear
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      tester.printToConsole('Dialog should now be visible');
      // Should show the onboarding dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.printToConsole('Onboarding dialog is found');
      // Onboard with the dialog
      final nextButton = find.widgetWithText(ElevatedButton, 'Next');
      await tester.tap(nextButton);
      expect(nextButton, findsOneWidget);
      tester.printToConsole('Next button tapped');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      // expect(find.widgetWithText(Text, 'Dashboard'), findsOneWidget);
      expect(find.byType(ProfileView), findsAtLeastNWidgets(1));
      tester.printToConsole('Dashboard is displayed');

      // // Dismiss the dialog and verify button state resets
      // final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      // await tester.tap(cancelButton);
      // await tester.pumpAndSettle();

      // Button should be visible again after dialog dismissal
      // expect(find.byType(OnboardingButton), findsOneWidget);
    });

    testWidgets('App handles rapid user interactions gracefully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final getStartedButton = find.byType(OnboardingButton);

      // Rapidly tap the button multiple times
      for (int i = 0; i < 2; i++) {
        await tester.tap(getStartedButton);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Clean up any opened dialogs
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Should handle rapid interactions without crashing
      expect(tester.takeException(), isNull);
    });
  });
}
