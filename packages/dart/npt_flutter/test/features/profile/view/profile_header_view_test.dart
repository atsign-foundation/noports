import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/view/pin_favorites_switch.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile/widgets/profile_header_column.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../profile_list/view/profile_list_view_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileHeaderView Widget Tests', () {
    late MockProfileListBloc mockProfileListBloc;
    late MockSettingsBloc mockSettingsBloc;
    late MockProfilesSelectedCubit mockProfilesSelectedCubit;

    setUpAll(() {
      // Provide dummy values before any test runs
      provideDummy<ProfileListState>(const ProfileListInitial());
      provideDummy<SettingsState>(const SettingsInitial());
      provideDummy<ProfilesSelectedState>(const ProfilesSelectedState({}));

      // Disable overflow errors in tests
      FlutterError.onError = (FlutterErrorDetails details) {
        final exception = details.exception;
        final isOverflowError =
            exception is AssertionError &&
            exception.toString().contains('overflowed');

        if (isOverflowError ||
            details.toString().contains('RenderFlex overflowed')) {
          // Ignore overflow errors during testing
          return;
        }
        FlutterError.presentError(details);
      };
    });

    setUp(() {
      mockProfileListBloc = MockProfileListBloc();
      mockSettingsBloc = MockSettingsBloc();
      mockProfilesSelectedCubit = MockProfilesSelectedCubit();

      // Default stubs
      when(mockProfileListBloc.stream).thenAnswer((_) => const Stream.empty());
      when(mockProfileListBloc.state).thenReturn(const ProfileListInitial());
      when(mockSettingsBloc.stream).thenAnswer((_) => const Stream.empty());
      when(mockSettingsBloc.state).thenReturn(const SettingsInitial());
      when(
        mockProfilesSelectedCubit.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        mockProfilesSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({}));
    });

    Widget createTestWidget({
      required ProfileListState profileListState,
      required SettingsState settingsState,
    }) {
      when(mockProfileListBloc.state).thenReturn(profileListState);
      when(
        mockProfileListBloc.stream,
      ).thenAnswer((_) => Stream.value(profileListState));

      when(mockSettingsBloc.state).thenReturn(settingsState);
      when(
        mockSettingsBloc.stream,
      ).thenAnswer((_) => Stream.value(settingsState));

      when(
        mockProfilesSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({}));
      when(
        mockProfilesSelectedCubit.stream,
      ).thenAnswer((_) => Stream.value(const ProfilesSelectedState({})));

      return MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileListBloc>.value(value: mockProfileListBloc),
              BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
              BlocProvider<ProfilesSelectedCubit>.value(
                value: mockProfilesSelectedCubit,
              ),
            ],
            child: const ProfileHeaderView(),
          ),
        ),
      );
    }

    group('ProfileListInitial State', () {
      testWidgets('should trigger ProfileListLoadEvent', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListInitial(),
            settingsState: const SettingsInitial(),
          ),
        );

        verify(mockProfileListBloc.add(const ProfileListLoadEvent())).called(1);
      });
    });

    group('ProfileListLoading State', () {
      testWidgets('should display LoaderBar and RefreshButton', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListLoading(),
            settingsState: const SettingsInitial(),
          ),
        );

        expect(find.byType(LoaderBar), findsOneWidget);
        expect(find.byType(ProfileListRefreshButton), findsOneWidget);
      });
    });

    group('ProfileListFailedLoad State', () {
      testWidgets('should display error message and RefreshButton', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListFailedLoad(),
            settingsState: const SettingsInitial(),
          ),
        );
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(
          find.byType(ProfileHeaderView),
        );
        final String expectedErrorMessage = AppLocalizations.of(
          context,
        )!.errorProfileLoadFailed;

        expect(find.text(expectedErrorMessage), findsOneWidget);
        expect(find.byType(ProfileListRefreshButton), findsOneWidget);
      });
    });

    group('ProfileListLoaded State', () {
      const testProfiles = ['uuid1', 'uuid2'];

      testWidgets('should display Spinner when Settings not loaded', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListLoaded(profiles: testProfiles),
            settingsState: const SettingsInitial(),
          ),
        );

        expect(find.byType(Spinner), findsOneWidget);
      });

      testWidgets('should display Minimal layout', (tester) async {
        const settings = Settings(
          relayAtsign: '@relay',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          language: Language.english,
        );

        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListLoaded(profiles: testProfiles),
            settingsState: const SettingsLoaded(settings: settings),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSelectAllBox), findsOneWidget);
        expect(find.byType(ProfileHeaderColumn), findsNWidgets(2));
        expect(find.byType(PinFavoritesSwitch), findsOneWidget);

        final BuildContext context = tester.element(
          find.byType(ProfileHeaderView),
        );
        final strings = AppLocalizations.of(context)!;

        expect(find.text(strings.profileName), findsOneWidget);
        expect(find.text(strings.status), findsOneWidget);
      });

      testWidgets('should display SSH Style layout', (tester) async {
        const settings = Settings(
          relayAtsign: '@relay',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.sshStyle,
          language: Language.english,
        );

        await tester.pumpWidget(
          createTestWidget(
            profileListState: const ProfileListLoaded(profiles: testProfiles),
            settingsState: const SettingsLoaded(settings: settings),
          ),
        );
        await tester.pump();

        // Verify SSH style layout has 4 header columns (vs 2 for minimal)
        expect(find.byType(ProfileSelectAllBox), findsOneWidget);
        expect(find.byType(ProfileHeaderColumn), findsNWidgets(4));
        expect(find.byType(PinFavoritesSwitch), findsOneWidget);

        final BuildContext context = tester.element(
          find.byType(ProfileHeaderView),
        );
        final strings = AppLocalizations.of(context)!;

        expect(find.text(strings.profileName), findsOneWidget);
        expect(find.text(strings.deviceName), findsOneWidget);
        expect(find.text(strings.serviceMapping), findsOneWidget);
        expect(find.text(strings.status), findsOneWidget);
      });
    });
  });
}
