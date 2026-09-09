import 'package:at_client/at_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import 'profile_list_view_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ProfileListBloc>(),
  MockSpec<ProfileCacheCubit>(),
  MockSpec<ProfileBloc>(),
  MockSpec<BackupKeyCubit>(),
  MockSpec<OnboardingCubit>(),
  MockSpec<SettingsBloc>(),
  MockSpec<ProfilesSelectedCubit>(),
  MockSpec<FavoriteBloc>(),
])
void main() {
  group('ProfileListView Widget Tests', () {
    late MockProfileListBloc mockProfileListBloc;
    late MockProfileCacheCubit mockProfileCacheCubit;
    late MockProfileBloc mockProfileBloc;
    late MockBackupKeyCubit mockBackupKeyCubit;
    late MockOnboardingCubit mockOnboardingCubit;
    late MockSettingsBloc mockSettingsBloc;
    late MockProfilesSelectedCubit mockProfilesSelectedCubit;
    late MockFavoriteBloc mockFavoriteBloc;

    const testUuid1 = 'test-uuid-1';
    const testUuid2 = 'test-uuid-2';
    const testUuids = [testUuid1, testUuid2];

    final testProfile1 = Profile(
      testUuid1,
      displayName: 'Test Profile 1',
      sshnpdAtsign: '@test1'.toAtsign(),
      relayAtsign: '@relay1'.toAtsign(),
      deviceName: 'device1',
      remotePort: 22,
      localPort: 2022,
    );

    final testSettings = Settings(
      relayAtsign: '@rv_eu'.toAtsign(),
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      darkMode: false,
      language: Language.english,
    );

    setUpAll(() {
      // Disable overflow errors in tests
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          // Ignore overflow errors during testing
          return;
        }
        FlutterError.presentError(details);
      };
    });

    setUp(() {
      mockProfileListBloc = MockProfileListBloc();
      mockProfileCacheCubit = MockProfileCacheCubit();
      mockProfileBloc = MockProfileBloc();
      mockBackupKeyCubit = MockBackupKeyCubit();
      mockOnboardingCubit = MockOnboardingCubit();
      mockSettingsBloc = MockSettingsBloc();
      mockProfilesSelectedCubit = MockProfilesSelectedCubit();
      mockFavoriteBloc = MockFavoriteBloc();

      // Provide dummy values for non-nullable states
      provideDummy<ProfileListState>(const ProfileListInitial());
      provideDummy<ProfileCacheState>(const ProfileCacheState({}));
      provideDummy<ProfileState>(const ProfileInitial('test'));
      provideDummy<OnboardingState>(
        OnboardingState(
          atsign: '@test'.toAtsign(),
          status: OnboardingStatus.onboarded,
          rootDomain: 'root.atsign.org',
        ),
      );
      provideDummy<SettingsState>(const SettingsInitial());
      provideDummy<ProfilesSelectedState>(const ProfilesSelectedState({}));
      provideDummy<FavoritesState>(const FavoritesInitial());

      // Set up default mock behaviors
      when(mockProfileListBloc.state).thenReturn(const ProfileListInitial());
      when(
        mockProfileListBloc.stream,
      ).thenAnswer((_) => Stream.value(const ProfileListInitial()));

      when(mockProfileBloc.uuid).thenReturn(testUuid1);
      when(
        mockProfileBloc.state,
      ).thenReturn(ProfileLoaded(testUuid1, profile: testProfile1));
      when(mockProfileBloc.stream).thenAnswer(
        (_) => Stream.value(ProfileLoaded(testUuid1, profile: testProfile1)),
      );

      when(
        mockProfileCacheCubit.getProfileBloc(any),
      ).thenReturn(mockProfileBloc);

      when(mockBackupKeyCubit.state).thenReturn(false);
      when(mockBackupKeyCubit.stream).thenAnswer((_) => Stream.value(false));
      when(mockBackupKeyCubit.getBackupKeyStatus()).thenAnswer(
        (_) => Future.value(true),
      ); // Mock as already backed up to avoid dialog

      when(mockOnboardingCubit.state).thenReturn(
        OnboardingState(
          atsign: '@test'.toAtsign(),
          status: OnboardingStatus.onboarded,
          rootDomain: 'root.atsign.org',
        ),
      );
      when(mockOnboardingCubit.stream).thenAnswer(
        (_) => Stream.value(
          OnboardingState(
            atsign: '@test'.toAtsign(),
            status: OnboardingStatus.onboarded,
            rootDomain: 'root.atsign.org',
          ),
        ),
      );

      when(
        mockSettingsBloc.state,
      ).thenReturn(SettingsLoaded(settings: testSettings));
      when(
        mockSettingsBloc.stream,
      ).thenAnswer((_) => Stream.value(SettingsLoaded(settings: testSettings)));

      when(
        mockProfilesSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({}));
      when(
        mockProfilesSelectedCubit.stream,
      ).thenAnswer((_) => Stream.value(const ProfilesSelectedState({})));

      when(mockFavoriteBloc.state).thenReturn(const FavoritesInitial());
      when(
        mockFavoriteBloc.stream,
      ).thenAnswer((_) => Stream.value(const FavoritesInitial()));
    });

    Widget createWidgetUnderTest(ProfileListState state) {
      when(mockProfileListBloc.state).thenReturn(state);
      when(mockProfileListBloc.stream).thenAnswer((_) => Stream.value(state));

      return MultiBlocProvider(
        providers: [
          BlocProvider<ProfileListBloc>.value(value: mockProfileListBloc),
          BlocProvider<ProfileCacheCubit>.value(value: mockProfileCacheCubit),
          BlocProvider<BackupKeyCubit>.value(value: mockBackupKeyCubit),
          BlocProvider<OnboardingCubit>.value(value: mockOnboardingCubit),
          BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
          BlocProvider<ProfilesSelectedCubit>.value(
            value: mockProfilesSelectedCubit,
          ),
          BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
        ],
        child: MaterialApp(
          navigatorKey: App.navState, // Use the App.navState directly
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfileListView()),
        ),
      );
    }

    group('ProfileList Loading States', () {
      testWidgets('should display Spinner for initial and loading states', (
        WidgetTester tester,
      ) async {
        // Set test window size to match production
        tester.view.physicalSize = const Size(1053, 691);
        tester.view.devicePixelRatio = 1.0;

        // Test ProfileListInitial state
        await tester.pumpWidget(
          createWidgetUnderTest(const ProfileListInitial()),
        );
        await tester.pump();
        expect(find.byType(Spinner), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);

        // Test ProfileListLoading state
        await tester.pumpWidget(
          createWidgetUnderTest(const ProfileListLoading()),
        );
        await tester.pump();
        expect(find.byType(Spinner), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
      });
    });

    group('ProfileListFailedLoad State', () {
      testWidgets(
        'should display ProfileListFailedLoadContent when state is ProfileListFailedLoad',
        (WidgetTester tester) async {
          // Set test window size to match production
          tester.view.physicalSize = const Size(1053, 691);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            createWidgetUnderTest(const ProfileListFailedLoad()),
          );
          await tester.pump();

          expect(find.byType(ProfileListFailedLoadContent), findsOneWidget);
          expect(find.byType(Spinner), findsNothing);
        },
      );
    });

    group('ProfileListLoaded State', () {
      testWidgets('should display empty state when no profiles are loaded', (
        WidgetTester tester,
      ) async {
        // Set test window size to match production
        tester.view.physicalSize = const Size(1053, 691);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createWidgetUnderTest(const ProfileListLoaded(profiles: [])),
        );
        await tester.pump();

        // Should not show spinner
        expect(find.byType(Spinner), findsNothing);

        // Should show main layout components
        expect(find.byType(Column), findsWidgets);

        // Should show basic action buttons (Add and Import only when empty)
        expect(find.byType(ProfileListAddButton), findsOneWidget);
        expect(find.byType(ProfileListImportButton), findsOneWidget);

        // Should not show profile-specific buttons when empty
        expect(find.byType(ProfileSelectedExportButton), findsNothing);
        expect(find.byType(ProfileSelectedDeleteButton), findsNothing);

        // Should show empty state content
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DemoProfileInfoWidget), findsOneWidget);

        // Should not show profile header or profile views when empty
        expect(find.byType(ProfileHeaderView), findsNothing);
        expect(find.byType(ListView), findsNothing);
      });

      testWidgets('should display profiles when profiles are loaded', (
        WidgetTester tester,
      ) async {
        // Set test window size to match production
        tester.view.physicalSize = const Size(1053, 691);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createWidgetUnderTest(const ProfileListLoaded(profiles: testUuids)),
        );
        await tester.pump();

        // Should not show spinner
        expect(find.byType(Spinner), findsNothing);

        // Should show main layout components
        expect(find.byType(Column), findsWidgets);

        // Should show all action buttons when profiles exist
        expect(find.byType(ProfileListAddButton), findsOneWidget);
        expect(find.byType(ProfileListImportButton), findsOneWidget);
        expect(find.byType(ProfileSelectedExportButton), findsOneWidget);
        expect(find.byType(ProfileSelectedDeleteButton), findsOneWidget);

        // Should show profile header and profile list
        expect(find.byType(ProfileHeaderView), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);

        // Should show profile views (one for each profile)
        expect(find.byType(ProfileView), findsNWidgets(testUuids.length));

        // Should not show empty state content
        expect(find.byType(SvgPicture), findsNothing);
        expect(find.byType(DemoProfileInfoWidget), findsNothing);

        // Verify ProfileCacheCubit.getProfileBloc was called for each profile
        verify(
          mockProfileCacheCubit.getProfileBloc(testUuid1),
        ).called(greaterThanOrEqualTo(1));
        verify(
          mockProfileCacheCubit.getProfileBloc(testUuid2),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('should provide correct BlocProvider keys for profiles', (
        WidgetTester tester,
      ) async {
        // Set test window size to match production
        tester.view.physicalSize = const Size(1053, 691);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createWidgetUnderTest(const ProfileListLoaded(profiles: testUuids)),
        );
        await tester.pump();

        // Check that BlocProvider keys are set correctly for each profile
        expect(
          find.byKey(const Key("ProfileListView-BlocProvider-$testUuid1")),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key("ProfileListView-BlocProvider-$testUuid2")),
          findsOneWidget,
        );
      });
    });
  });
}
