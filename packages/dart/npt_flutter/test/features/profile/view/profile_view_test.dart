import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import 'profile_view_test.mocks.dart';

// Mock classes for testing
@GenerateNiceMocks([
  MockSpec<ProfileBloc>(),
  MockSpec<SettingsBloc>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileView Widget Tests', () {
    late MockProfileBloc mockProfileBloc;
    late MockSettingsBloc mockSettingsBloc;

    const testUuid = 'test-uuid-123';
    const testProfile = Profile(
      testUuid,
      displayName: 'Test Profile',
      sshnpdAtsign: '@test_device',
      deviceName: 'test-device',
      remotePort: 22,
      localPort: 2222,
      relayAtsign: '@relay_test',
    );

    const testSettings = Settings(
      relayAtsign: '@rv_eu',
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      darkMode: false,
      language: Language.english,
    );

    setUp(() {
      mockProfileBloc = MockProfileBloc();
      mockSettingsBloc = MockSettingsBloc();

      // Provide dummy values for the mocks
      provideDummy<ProfileState>(const ProfileInitial(testUuid));
      provideDummy<SettingsState>(const SettingsInitial());
    });

    tearDown(() {
      reset(mockProfileBloc);
      reset(mockSettingsBloc);
    });

    Widget createTestWidget({
      required ProfileState profileState,
      required SettingsState settingsState,
      Stream<ProfileState>? profileStream,
      Stream<SettingsState>? settingsStream,
    }) {
      whenListen(
        mockProfileBloc,
        profileStream ?? Stream.value(profileState),
        initialState: profileState,
      );

      whenListen(
        mockSettingsBloc,
        settingsStream ?? Stream.value(settingsState),
        initialState: settingsState,
      );

      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: mockProfileBloc),
              BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
            ],
            child: const ProfileView(),
          ),
        ),
      );
    }

    group('ProfileInitial State', () {
      testWidgets('should trigger ProfileLoadEvent when state is ProfileInitial', (tester) async {
        const profileState = ProfileInitial(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        verify(mockProfileBloc.add(const ProfileLoadEvent())).called(1);
      });

      testWidgets('should display LoaderBar and ProfileRefreshButton', (tester) async {
        const profileState = ProfileInitial(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        expect(find.byType(LoaderBar), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });
    });

    group('ProfileLoading State', () {
      testWidgets('should display LoaderBar and ProfileRefreshButton', (tester) async {
        const profileState = ProfileLoading(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        expect(find.byType(LoaderBar), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });

      testWidgets('should center the loading content', (tester) async {
        const profileState = ProfileLoading(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.center));
      });
    });

    group('ProfileFailedLoad State', () {
      testWidgets('should display error message and ProfileRefreshButton', (tester) async {
        const profileState = ProfileFailedLoad(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        expect(find.text('Error loading profile. Please try again.'), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });

      testWidgets('should center the error content', (tester) async {
        const profileState = ProfileFailedLoad(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.center));
      });
    });

    group('ProfileLoadedState with Settings', () {
      group('Minimal View Layout', () {
        testWidgets('should display ProfileViewMinimal when viewLayout is minimal', (tester) async {
          const profileState = ProfileLoaded(testUuid, profile: testProfile);
          const settingsState = SettingsLoaded(
            settings: Settings(
              relayAtsign: '@rv_eu',
              overrideRelay: false,
              viewLayout: PreferredViewLayout.minimal,
              darkMode: false,
              language: Language.english,
            ),
          );

          await tester.pumpWidget(createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ));
          await tester.pump();

          expect(find.byType(ProfileViewMinimal), findsOneWidget);
          expect(find.byType(ProfileViewSshStyle), findsNothing);
          expect(find.byType(Spinner), findsNothing);
        });
      });

      group('SSH Style View Layout', () {
        testWidgets('should display ProfileViewSshStyle when viewLayout is sshStyle', (tester) async {
          const profileState = ProfileLoaded(testUuid, profile: testProfile);
          const settingsState = SettingsLoaded(
            settings: Settings(
              relayAtsign: '@rv_eu',
              overrideRelay: false,
              viewLayout: PreferredViewLayout.sshStyle,
              darkMode: false,
              language: Language.english,
            ),
          );

          await tester.pumpWidget(createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ));
          await tester.pump();

          expect(find.byType(ProfileViewSshStyle), findsOneWidget);
          expect(find.byType(ProfileViewMinimal), findsNothing);
          expect(find.byType(Spinner), findsNothing);
        });
      });

      group('No Settings State (null viewLayout)', () {
        testWidgets('should display Spinner when SettingsState is not SettingsLoadedState', (tester) async {
          const profileState = ProfileLoaded(testUuid, profile: testProfile);
          const settingsState = SettingsInitial();

          await tester.pumpWidget(createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ));
          await tester.pump();

          expect(find.byType(Spinner), findsOneWidget);
          expect(find.byType(ProfileViewMinimal), findsNothing);
          expect(find.byType(ProfileViewSshStyle), findsNothing);
        });

        testWidgets('should display Spinner when SettingsState is SettingsLoading', (tester) async {
          const profileState = ProfileLoaded(testUuid, profile: testProfile);
          const settingsState = SettingsLoading();

          await tester.pumpWidget(createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ));
          await tester.pump();

          expect(find.byType(Spinner), findsOneWidget);
          expect(find.byType(Center), findsOneWidget);
          expect(find.byType(ProfileViewMinimal), findsNothing);
          expect(find.byType(ProfileViewSshStyle), findsNothing);
        });
      });
    });

    group('BlocSelector Behavior', () {
      testWidgets('should react to SettingsBloc state changes for viewLayout', (tester) async {
        const profileState = ProfileLoaded(testUuid, profile: testProfile);

        // Start with minimal layout
        const initialSettingsState = SettingsLoaded(
          settings: Settings(
            relayAtsign: '@rv_eu',
            overrideRelay: false,
            viewLayout: PreferredViewLayout.minimal,
            darkMode: false,
            language: Language.english,
          ),
        );

        const updatedSettingsState = SettingsLoaded(
          settings: Settings(
            relayAtsign: '@rv_eu',
            overrideRelay: false,
            viewLayout: PreferredViewLayout.sshStyle,
            darkMode: false,
            language: Language.english,
          ),
        );

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: initialSettingsState,
          settingsStream: Stream.fromIterable([
            initialSettingsState,
            updatedSettingsState,
          ]),
        ));
        await tester.pump();

        // Should initially show minimal view
        expect(find.byType(ProfileViewMinimal), findsOneWidget);
        expect(find.byType(ProfileViewSshStyle), findsNothing);

        // Trigger state change
        await tester.pump();

        // Should now show SSH style view
        expect(find.byType(ProfileViewSshStyle), findsOneWidget);
        expect(find.byType(ProfileViewMinimal), findsNothing);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle ProfileFailedLoad state with fallback settings', (tester) async {
        const profileState = ProfileFailedLoad(testUuid);
        const settingsState = SettingsFailedLoad(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        expect(find.text('Error loading profile. Please try again.'), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
      });

      testWidgets('should handle state transitions correctly', (tester) async {
        const initialState = ProfileInitial(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: initialState,
          settingsState: settingsState,
          profileStream: Stream.fromIterable([
            initialState,
            const ProfileLoading(testUuid),
            const ProfileLoaded(testUuid, profile: testProfile),
          ]),
        ));

        // Initial state - should trigger load event
        await tester.pump();
        verify(mockProfileBloc.add(const ProfileLoadEvent())).called(1);
        expect(find.byType(LoaderBar), findsOneWidget);

        // Loading state
        await tester.pump();
        expect(find.byType(LoaderBar), findsOneWidget);

        // Loaded state
        await tester.pump();
        expect(find.byType(ProfileViewMinimal), findsOneWidget);
      });
    });

    group('Widget Structure and Layout', () {
      testWidgets('should have proper widget hierarchy for loading state', (tester) async {
        const profileState = ProfileLoading(testUuid);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        // Check the widget hierarchy
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(MultiBlocProvider), findsOneWidget);
        expect(find.byType(ProfileView), findsOneWidget);
        expect(find.byType(BlocBuilder<ProfileBloc, ProfileState>), findsOneWidget);
      });

      testWidgets('should have proper widget hierarchy for loaded state', (tester) async {
        const profileState = ProfileLoaded(testUuid, profile: testProfile);
        const settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(createTestWidget(
          profileState: profileState,
          settingsState: settingsState,
        ));
        await tester.pump();

        // Check the widget hierarchy includes BlocSelector
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(ProfileView), findsOneWidget);
        expect(find.byType(BlocBuilder<ProfileBloc, ProfileState>), findsOneWidget);
        expect(find.byType(BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>), findsOneWidget);
      });
    });
  });
}
