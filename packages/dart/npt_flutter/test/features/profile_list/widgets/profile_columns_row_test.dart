import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

void main() {
  const double tableWidth = 800;
  const double regionWidth =
      tableWidth - 3 * kProfileIconColumnWidth - 4 * kProfileColumnGap;

  Key headerKey(ProfileColumn column) =>
      ValueKey<String>('header-${column.name}');
  Key rowKey(ProfileColumn column) => ValueKey<String>('row-${column.name}');
  Key dividerKey(ProfileColumn column) =>
      ValueKey<String>('divider-${column.name}');

  double availableFor(PreferredViewLayout layout) {
    final int columnCount = ProfileColumn.resizableFor(layout).length;
    return regionWidth - kProfileColumnGap * (columnCount - 1);
  }

  Widget buildTable(PreferredViewLayout layout, ProfileColumnsCubit cubit) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<ProfileColumnsCubit>.value(
          value: cubit,
          child: Center(
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileColumnsRow(
                    layout: layout,
                    select: const SizedBox(),
                    cellBuilder: (ProfileColumn column, double width) =>
                        SizedBox(key: headerKey(column), height: 40),
                    dividerBuilder:
                        (
                          ProfileColumn column,
                          double width,
                          double availableWidth,
                        ) => ProfileColumnDivider(
                          key: dividerKey(column),
                          layout: layout,
                          column: column,
                          width: width,
                          availableWidth: availableWidth,
                        ),
                    favorite: const SizedBox(),
                    menu: const SizedBox(),
                  ),
                  ProfileColumnsRow(
                    layout: layout,
                    select: const SizedBox(),
                    cellBuilder: (ProfileColumn column, double width) =>
                        SizedBox(key: rowKey(column), height: 40),
                    favorite: const SizedBox(),
                    menu: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double widthOf(WidgetTester tester, Key key) {
    return tester.getSize(find.byKey(key)).width;
  }

  double leftOf(WidgetTester tester, Key key) {
    return tester.getTopLeft(find.byKey(key)).dx;
  }

  Future<void> dragDivider(
    WidgetTester tester,
    ProfileColumn column,
    double dx,
  ) async {
    await tester.drag(
      find.byKey(dividerKey(column)),
      Offset(dx, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
  }

  group('ProfileColumnsRow', () {
    late ProfileColumnsCubit cubit;

    setUp(() {
      cubit = ProfileColumnsCubit();
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('fills the region with the default proportions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.sshStyle, cubit));

      final double available = availableFor(PreferredViewLayout.sshStyle);
      expect(
        widthOf(tester, headerKey(ProfileColumn.profileName)),
        closeTo(available * 0.24, 0.01),
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.deviceName)),
        closeTo(available * 0.24, 0.01),
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.serviceMapping)),
        closeTo(available * 0.24, 0.01),
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.status)),
        closeTo(available * 0.28, 0.01),
      );
    });

    testWidgets('renders one divider between each pair of resizable columns', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.sshStyle, cubit));
      expect(find.byType(ProfileColumnDivider), findsNWidgets(3));

      await tester.pumpWidget(buildTable(PreferredViewLayout.minimal, cubit));
      expect(find.byType(ProfileColumnDivider), findsOneWidget);
    });

    testWidgets('header and rows share the same column geometry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.sshStyle, cubit));
      await dragDivider(tester, ProfileColumn.deviceName, 37);

      for (final ProfileColumn column in ProfileColumn.resizableFor(
        PreferredViewLayout.sshStyle,
      )) {
        expect(
          widthOf(tester, rowKey(column)),
          closeTo(widthOf(tester, headerKey(column)), 0.001),
        );
        expect(
          leftOf(tester, rowKey(column)),
          closeTo(leftOf(tester, headerKey(column)), 0.001),
        );
      }
    });

    testWidgets('dragging a divider grows the column and status absorbs it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.sshStyle, cubit));
      final double nameBefore = widthOf(
        tester,
        headerKey(ProfileColumn.profileName),
      );
      final double deviceBefore = widthOf(
        tester,
        headerKey(ProfileColumn.deviceName),
      );
      final double statusBefore = widthOf(
        tester,
        headerKey(ProfileColumn.status),
      );

      await dragDivider(tester, ProfileColumn.profileName, 50);

      expect(
        widthOf(tester, headerKey(ProfileColumn.profileName)),
        closeTo(nameBefore + 50, 0.01),
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.deviceName)),
        closeTo(deviceBefore, 0.01),
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.status)),
        closeTo(statusBefore - 50, 0.01),
      );
      expect(
        widthOf(tester, rowKey(ProfileColumn.profileName)),
        closeTo(nameBefore + 50, 0.01),
      );
    });

    testWidgets('a column stops at its minimum width when dragged left', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.minimal, cubit));

      await dragDivider(tester, ProfileColumn.profileName, -1000);

      final double available = availableFor(PreferredViewLayout.minimal);
      expect(
        widthOf(tester, headerKey(ProfileColumn.profileName)),
        kProfileTextColumnMinWidth,
      );
      expect(
        widthOf(tester, headerKey(ProfileColumn.status)),
        closeTo(available - kProfileTextColumnMinWidth, 0.01),
      );
    });

    testWidgets(
      'status stops at its button width when a column is dragged right',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTable(PreferredViewLayout.minimal, cubit));

        await dragDivider(tester, ProfileColumn.profileName, 1000);

        final double available = availableFor(PreferredViewLayout.minimal);
        expect(
          widthOf(tester, headerKey(ProfileColumn.status)),
          kProfileIconColumnWidth,
        );
        expect(
          widthOf(tester, headerKey(ProfileColumn.profileName)),
          closeTo(available - kProfileIconColumnWidth, 0.01),
        );
      },
    );

    testWidgets('shows the column resize cursor over a divider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTable(PreferredViewLayout.sshStyle, cubit));

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(
        tester.getCenter(find.byKey(dividerKey(ProfileColumn.profileName))),
      );
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.resizeColumn,
      );
    });
  });
}
