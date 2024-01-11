import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/terminal_session_controller.dart';
import 'package:sshnp_gui/src/presentation/screens/terminal_screen.dart';

class TerminalScreenRobot {
  TerminalScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpTerminalScreen(
      {TerminalSessionController? mockTerminalSessionController,
      TerminalSessionListController? mockTerminalSessionListController}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          if (mockTerminalSessionController != null)
            terminalSessionController.overrideWith(() => mockTerminalSessionController),
          if (mockTerminalSessionListController != null)
            terminalSessionListController.overrideWith(() => mockTerminalSessionListController),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TerminalScreen(),
        )));
  }

  void findNoTerminalSession() {
    final finder = find.text('No active terminal sessions');
    expect(finder, findsOneWidget);
  }

  void findNoTerminalSessionHelp() {
    final finder = find.text('Create a new session from the home screen');

    expect(finder, findsOneWidget);
  }
}
