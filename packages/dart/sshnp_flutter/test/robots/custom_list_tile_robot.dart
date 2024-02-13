import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_flutter/src/presentation/widgets/custom_list_tile.dart';

class CustomListTileRobot {
  CustomListTileRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpCustomListTile(
      {required CustomListTile customListTile}) async {
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: customListTile,
        )));
  }

  void findListTile() {
    final finder = find.text('Available Connections');
    expect(finder, findsOneWidget);
  }

  void findEmailListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.email_outlined);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Email');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Guaranteed quick response');
    expect(textFinderTwo, findsOneWidget);
  }

  void findDiscordListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.discord);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Discord');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Join our server for help');
    expect(textFinderTwo, findsOneWidget);
  }

  void findFAQListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.help_center_outlined);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('FAQ');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Frequently asked questions');
    expect(textFinderTwo, findsOneWidget);
  }

  void findPrivacyPolicyListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.account_balance_wallet_outlined);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Privacy Policy');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Check our terms of service');
    expect(textFinderTwo, findsOneWidget);
  }

  void findSSHKeyManagementListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.vpn_key_outlined);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('SSH Key Management');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Edit, add and delete SSH Keys');
    expect(textFinderTwo, findsOneWidget);
  }

  void findSwitchAtsignListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.switch_account_outlined);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Switch atsign');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo =
        find.text('Select a different atsign to onboard with');
    expect(textFinderTwo, findsOneWidget);
  }

  void findBackUpYourKeyListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.bookmark_outline);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Backup Your Keys');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo = find.text('Save a pair of your atKeys');
    expect(textFinderTwo, findsOneWidget);
  }

  void findResetAtsignListTile() {
    final filledButtonFinder = find.byType(FilledButton);
    expect(filledButtonFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.rotate_right);
    expect(iconFinder, findsOneWidget);

    final textFinderOne = find.text('Reset App');
    expect(textFinderOne, findsOneWidget);
    final textFinderTwo =
        find.text('App will be reset and you will be logged out');
    expect(textFinderTwo, findsOneWidget);
  }
}
