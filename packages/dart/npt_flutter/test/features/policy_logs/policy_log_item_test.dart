import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/policy_logs/widgets/policy_log_item.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

void main() {
  Future<RenderParagraph> pumpSummary(
    WidgetTester tester,
    String allowedServices,
  ) async {
    tester.view.physicalSize = const Size(1920, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PolicyLogItem(
            timestamp: '2026-10-07 12:00:00',
            fromAtsign: '@policy'.toAtsign(),
            toAtsign: '@policy'.toAtsign(),
            type: 'policy request',
            deviceName: 'lab01',
            deviceGroup: 'labs',
            allowedServices: allowedServices,
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.text(allowedServices));
  }

  testWidgets('a denial reason wraps onto further lines rather than being '
      'cut off', (tester) async {
    const summary =
        'Request: @alice → @lab (DENIED: outside the hours this device allows)';
    final paragraph = await pumpSummary(tester, summary);

    final oneLine = paragraph.getMaxIntrinsicHeight(double.infinity);
    expect(paragraph.size.height, greaterThan(oneLine));
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('a summary longer than four lines is cut, and the tooltip holds '
      'all of it', (tester) async {
    final summary = 'Request: @alice → @lab (DENIED: ${'no permission ' * 20})';
    final paragraph = await pumpSummary(tester, summary);

    expect(paragraph.didExceedMaxLines, isTrue);
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .where((t) => t.message == summary),
      hasLength(1),
    );
  });
}
