import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/settings/widgets/advance_section.dart';
import 'package:npt_flutter/features/settings/widgets/dashboard_section.dart';
import 'package:npt_flutter/features/settings/widgets/default_relay_section.dart';
import 'package:npt_flutter/features/settings/widgets/language_section.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:npt_flutter/widgets/custom_card.dart';
import 'package:npt_flutter/widgets/custom_text_button.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import 'settings_view_test.mocks.dart';

@GenerateNiceMocks([MockSpec<SettingsBloc>(), MockSpec<EnableLoggingCubit>()])
void main() {
  group('SettingsView Widget Tests', () {
    late MockSettingsBloc mockSettingsBloc;
    late MockEnableLoggingCubit mockEnableLoggingCubit;

    final testSettings = Settings(
      relayAtsign: '@rv_eu'.toAtsign(),
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      darkMode: false,
      language: Language.english,
    );

    setUp(() {
      mockSettingsBloc = MockSettingsBloc();
      mockEnableLoggingCubit = MockEnableLoggingCubit();
      // final a = EnableLoggingCubit();

      // Provide dummy values for non-nullable states
      provideDummy<SettingsState>(const SettingsInitial());

      // Set up default mock behaviors
      when(mockSettingsBloc.state).thenReturn(const SettingsInitial());
      when(
        mockSettingsBloc.stream,
      ).thenAnswer((_) => Stream.value(const SettingsInitial()));

      when(mockEnableLoggingCubit.state).thenReturn(false);
      when(
        mockEnableLoggingCubit.stream,
      ).thenAnswer((_) => Stream.value(false));
    });

    Widget createWidgetUnderTest(SettingsState state) {
      when(mockSettingsBloc.state).thenReturn(state);
      when(mockSettingsBloc.stream).thenAnswer((_) => Stream.value(state));

      return MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
              BlocProvider<EnableLoggingCubit>.value(
                value: mockEnableLoggingCubit,
              ),
            ],
            child: const SettingsView(),
          ),
        ),
      );
    }

    group('SettingsInitial State', () {
      testWidgets('should display Spinner when state is SettingsInitial', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createWidgetUnderTest(const SettingsInitial()));
        await tester.pump();

        expect(find.byType(Spinner), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);

        // Should trigger settings load event
        verify(
          mockSettingsBloc.add(const SettingsLoadEvent()),
        ).called(greaterThanOrEqualTo(1));
      });
    });

    group('SettingsLoading State', () {
      testWidgets('should display Spinner when state is SettingsLoading', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createWidgetUnderTest(const SettingsLoading()));
        await tester.pump();

        expect(find.byType(Spinner), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
      });
    });

    group('SettingsLoaded State', () {
      testWidgets('should display all main components when loaded', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(SettingsLoaded(settings: testSettings)),
        );
        await tester.pump();

        // Should not show spinner
        expect(find.byType(Spinner), findsNothing);

        // Should show main layout
        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Row), findsWidgets);

        // Should show the two main cards
        expect(find.byType(CustomCard), findsAtLeastNWidgets(2));
      });

      testWidgets('should display settings rail with action buttons', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(SettingsLoaded(settings: testSettings)),
        );
        await tester.pump();

        // Should show custom text buttons
        expect(find.byType(CustomTextButton), findsNWidgets(6));
      });

      testWidgets('should display settings content sections', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(SettingsLoaded(settings: testSettings)),
        );
        await tester
            .pumpAndSettle(); // Use pumpAndSettle to wait for all animations

        // Should show all settings sections
        expect(find.byType(DefaultRelaySection), findsOneWidget);
        expect(find.byType(DashboardSection), findsOneWidget);

        await tester.dragUntilVisible(
          find.byType(AdvanceSection),
          find.byType(ListView),
          const Offset(0, -100), // Drag up to reveal AdvanceSection
        );
        expect(find.byType(AdvanceSection), findsOneWidget);
        await tester.dragUntilVisible(
          find.byType(LanguageSection),
          find.byType(ListView),
          const Offset(0, -100), // Drag up to reveal LanguageSection
        );
        expect(find.byType(LanguageSection), findsOneWidget);
      });

      testWidgets('should have proper widget hierarchy', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(SettingsLoaded(settings: testSettings)),
        );
        await tester.pump();

        // Check main structure
        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Row), findsAtLeastNWidgets(1));
        expect(find.byType(CustomCard), findsAtLeastNWidgets(2));
        expect(find.byType(Padding), findsWidgets);
      });
    });
  });
}
