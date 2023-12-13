import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/presentation/screens/support_screen.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_list_tile.dart';

class SupportScreenRobot {
  SupportScreenRobot(this.tester);

  final WidgetTester tester;

  Future<void> pumpSupportScreen({ConfigListController? mockConfigListController}) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SupportScreen(),
      ),
    ));
  }

  void findSupport() {
    final finder = find.text('Support');
    expect(finder, findsOneWidget);
  }

  void findSupportDescription() {
    final finder = find.text('Our team of experts is here to help! Select your preferred method below');
    expect(finder, findsOneWidget);
  }

  void findDiscordListTile() {
    final finder = find.widgetWithText(CustomListTile, 'Discord');
    expect(finder, findsOneWidget);
  }

  void findEmailListTile() {
    final finder = find.widgetWithText(CustomListTile, 'Email');
    expect(finder, findsOneWidget);
  }

  void findFAQListTile() {
    final finder = find.widgetWithText(CustomListTile, 'FAQ');
    expect(finder, findsOneWidget);
  }

  void findPrivacyPolicyListTile() {
    final finder = find.widgetWithText(CustomListTile, 'Privacy Policy');
    expect(finder, findsOneWidget);
  }
}
