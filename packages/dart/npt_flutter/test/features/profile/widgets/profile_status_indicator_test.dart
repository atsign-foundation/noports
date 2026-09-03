import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile/widgets/profile_status_indicator.dart';
import 'package:npt_flutter/features/profile_list/models/profile_column.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  Widget buildStatus(double width) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: StatusMessage(
              tooltip: 'Connected to the device',
              status: 'Connected',
              color: Colors.green,
              icon: PhosphorIcons.stop(PhosphorIconsStyle.fill),
            ),
          ),
        ),
      ),
    );
  }

  group('StatusMessage', () {
    testWidgets('shows the icon and text when the column is wide enough', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildStatus(200));

      expect(find.byType(PhosphorIcon), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('keeps only the icon at the status column minimum width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildStatus(ProfileColumn.status.minWidth));

      expect(find.byType(PhosphorIcon), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
