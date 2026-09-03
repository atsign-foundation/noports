import 'package:at_client/at_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/widgets/profile_delete_button.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
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
  MockSpec<ProfilesSelectedCubit>(),
  MockSpec<FavoriteBloc>(),
  MockSpec<FavoriteRepository>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileView Widget Tests', () {
    late MockProfileBloc mockProfileBloc;
    late MockSettingsBloc mockSettingsBloc;
    late MockProfilesSelectedCubit mockProfilesSelectedCubit;
    late MockFavoriteBloc mockFavoriteBloc;
    late MockFavoriteRepository mockFavoriteRepository;

    const testUuid = 'test-uuid-123';
    final testProfile = Profile(
      testUuid,
      displayName: 'Test Profile',
      sshnpdAtsign: '@test_device'.toAtsign(),
      deviceName: 'test-device',
      remotePort: 22,
      localPort: 2222,
      relayAtsign: '@relay_test'.toAtsign(),
    );

    final testSettings = Settings(
      relayAtsign: '@rv_eu'.toAtsign(),
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      darkMode: false,
      language: Language.english,
    );

    setUp(() {
      mockProfileBloc = MockProfileBloc();
      mockSettingsBloc = MockSettingsBloc();
      mockProfilesSelectedCubit = MockProfilesSelectedCubit();
      mockFavoriteBloc = MockFavoriteBloc();
      mockFavoriteRepository = MockFavoriteRepository();

      // Provide dummy values for the mocks
      provideDummy<ProfileState>(const ProfileInitial(testUuid));
      provideDummy<SettingsState>(const SettingsInitial());
      provideDummy<ProfilesSelectedState>(const ProfilesSelectedState({}));
      provideDummy<FavoritesState>(const FavoritesInitial());
    });

    tearDown(() {
      reset(mockProfileBloc);
      reset(mockSettingsBloc);
      reset(mockProfilesSelectedCubit);
      reset(mockFavoriteBloc);
      reset(mockFavoriteRepository);
    });

    Widget createTestWidget({
      required ProfileState profileState,
      required SettingsState settingsState,
      ProfilesSelectedState? profilesSelectedState,
      FavoritesState? favoritesState,
    }) {
      // Setup the bloc state mocks directly
      when(mockProfileBloc.state).thenReturn(profileState);
      when(mockSettingsBloc.state).thenReturn(settingsState);
      when(
        mockProfilesSelectedCubit.state,
      ).thenReturn(profilesSelectedState ?? const ProfilesSelectedState({}));
      when(
        mockFavoriteBloc.state,
      ).thenReturn(favoritesState ?? const FavoritesInitial());

      // Setup the stream mocks
      when(
        mockProfileBloc.stream,
      ).thenAnswer((_) => Stream.value(profileState));
      when(
        mockSettingsBloc.stream,
      ).thenAnswer((_) => Stream.value(settingsState));
      when(mockProfilesSelectedCubit.stream).thenAnswer(
        (_) => Stream.value(
          profilesSelectedState ?? const ProfilesSelectedState({}),
        ),
      );
      when(mockFavoriteBloc.stream).thenAnswer(
        (_) => Stream.value(favoritesState ?? const FavoritesInitial()),
      );

      return MaterialApp(
        // Use the App's navigation key to provide proper context for SizeConfig
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: mockProfileBloc),
              BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
              BlocProvider<ProfilesSelectedCubit>.value(
                value: mockProfilesSelectedCubit,
              ),
              BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
              BlocProvider<ProfileColumnsCubit>(
                create: (_) => ProfileColumnsCubit(),
              ),
            ],
            child: const ProfileView(),
          ),
        ),
      );
    }

    group('ProfileInitial State', () {
      testWidgets(
        'should trigger ProfileLoadEvent when state is ProfileInitial',
        (tester) async {
          const profileState = ProfileInitial(testUuid);
          final settingsState = SettingsLoaded(settings: testSettings);

          await tester.pumpWidget(
            createTestWidget(
              profileState: profileState,
              settingsState: settingsState,
            ),
          );
          await tester.pump();

          verify(
            mockProfileBloc.add(const ProfileLoadEvent()),
          ).called(greaterThanOrEqualTo(1));
        },
      );

      testWidgets('should display LoaderBar and ProfileRefreshButton', (
        tester,
      ) async {
        const profileState = ProfileInitial(testUuid);
        final settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(
          createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ),
        );
        await tester.pump();

        expect(find.byType(LoaderBar), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });
    });

    group('ProfileLoading State', () {
      testWidgets('should display loading components with proper layout', (
        tester,
      ) async {
        const profileState = ProfileLoading(testUuid);
        final settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(
          createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ),
        );
        await tester.pump();

        // Verify loading components are displayed
        expect(find.byType(LoaderBar), findsOneWidget);
        expect(find.byType(ProfileRefreshButton), findsOneWidget);
        expect(find.byType(Row), findsWidgets);

        // Verify layout is centered
        final rowWidget = tester.widget<Row>(find.byType(Row));
        expect(rowWidget.mainAxisAlignment, MainAxisAlignment.center);
      });
    });

    group('ProfileFailedLoad State', () {
      testWidgets('should display error message and ProfileDeleteButton', (
        tester,
      ) async {
        const profileState = ProfileFailedLoad(testUuid);
        final settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(
          createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ),
        );
        await tester.pump();

        // Get the context to access localized strings
        final BuildContext context = tester.element(find.byType(ProfileView));
        final String expectedErrorMessage = AppLocalizations.of(
          context,
        )!.errorProfileLoadFailed;

        // Find the exact localized error message
        expect(find.text(expectedErrorMessage), findsOneWidget);

        expect(find.byType(ProfileDeleteButton), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
      });

      testWidgets('should space the error content', (tester) async {
        const profileState = ProfileFailedLoad(testUuid);
        final settingsState = SettingsLoaded(settings: testSettings);

        await tester.pumpWidget(
          createTestWidget(
            profileState: profileState,
            settingsState: settingsState,
          ),
        );
        await tester.pump();

        final rowWidget = tester.widget<Row>(find.byType(Row));
        expect(rowWidget.mainAxisAlignment, MainAxisAlignment.spaceBetween);
      });
    });

    group('ProfileLoadedState with Settings', () {
      group('Minimal View Layout', () {
        testWidgets(
          'should display ProfileViewMinimal when viewLayout is minimal',
          (tester) async {
            final profileState = ProfileLoaded(testUuid, profile: testProfile);
            final settingsState = SettingsLoaded(settings: testSettings);

            await tester.pumpWidget(
              createTestWidget(
                profileState: profileState,
                settingsState: settingsState,
              ),
            );
            await tester.pump();

            expect(find.byType(ProfileViewMinimal), findsOneWidget);
          },
        );
      });

      group('SSH Style View Layout', () {
        testWidgets(
          'should display ProfileViewSshStyle when viewLayout is sshStyle',
          (tester) async {
            final profileState = ProfileLoaded(testUuid, profile: testProfile);
            final settingsWithSshStyle = Settings(
              relayAtsign: '@rv_eu'.toAtsign(),
              overrideRelay: false,
              viewLayout: PreferredViewLayout.sshStyle,
              darkMode: false,
              language: Language.english,
            );
            final settingsState = SettingsLoaded(
              settings: settingsWithSshStyle,
            );

            await tester.pumpWidget(
              createTestWidget(
                profileState: profileState,
                settingsState: settingsState,
              ),
            );
            await tester.pump();

            expect(find.byType(ProfileViewSshStyle), findsOneWidget);
          },
        );
      });

      group('No Settings State (null viewLayout)', () {
        testWidgets(
          'should display Spinner when SettingsState is not SettingsLoadedState',
          (tester) async {
            final profileState = ProfileLoaded(testUuid, profile: testProfile);
            const settingsState = SettingsInitial();

            await tester.pumpWidget(
              createTestWidget(
                profileState: profileState,
                settingsState: settingsState,
              ),
            );
            await tester.pump();

            expect(find.byType(Spinner), findsOneWidget);
            expect(find.byType(Center), findsOneWidget);
          },
        );

        testWidgets(
          'should display Spinner when SettingsState is SettingsLoading',
          (tester) async {
            final profileState = ProfileLoaded(testUuid, profile: testProfile);
            const settingsState = SettingsLoading();

            await tester.pumpWidget(
              createTestWidget(
                profileState: profileState,
                settingsState: settingsState,
              ),
            );
            await tester.pump();

            expect(find.byType(Spinner), findsOneWidget);
            expect(find.byType(Center), findsOneWidget);
          },
        );
      });
    });

    group('ProfileViewMinimal Widget Tests', () {
      Widget createMinimalTestWidget({
        ProfileState? profileState,
        ProfilesSelectedState? profilesSelectedState,
        FavoritesState? favoritesState,
      }) {
        // Setup the bloc state mocks
        when(mockProfileBloc.state).thenReturn(
          profileState ?? ProfileLoaded(testUuid, profile: testProfile),
        );
        when(
          mockProfilesSelectedCubit.state,
        ).thenReturn(profilesSelectedState ?? const ProfilesSelectedState({}));
        when(
          mockFavoriteBloc.state,
        ).thenReturn(favoritesState ?? const FavoritesInitial());

        // Setup the stream mocks
        when(mockProfileBloc.stream).thenAnswer(
          (_) => Stream.value(
            profileState ?? ProfileLoaded(testUuid, profile: testProfile),
          ),
        );
        when(mockProfilesSelectedCubit.stream).thenAnswer(
          (_) => Stream.value(
            profilesSelectedState ?? const ProfilesSelectedState({}),
          ),
        );
        when(mockFavoriteBloc.stream).thenAnswer(
          (_) => Stream.value(favoritesState ?? const FavoritesInitial()),
        );

        return MaterialApp(
          navigatorKey: App.navState,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileBloc>.value(value: mockProfileBloc),
                BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
                BlocProvider<ProfilesSelectedCubit>.value(
                  value: mockProfilesSelectedCubit,
                ),
                BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
                BlocProvider<ProfileColumnsCubit>(
                  create: (_) => ProfileColumnsCubit(),
                ),
              ],
              child: const ProfileViewMinimal(),
            ),
          ),
        );
      }

      testWidgets('should render without ProviderNotFoundException', (
        tester,
      ) async {
        await tester.pumpWidget(createMinimalTestWidget());
        await tester.pump();

        expect(find.byType(ProfileViewMinimal), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });

      testWidgets('should display all expected child widgets', (tester) async {
        await tester.pumpWidget(createMinimalTestWidget());
        await tester.pump();

        // Check for presence of key widgets within ProfileViewMinimal
        expect(find.byType(ProfileSelectBox), findsOneWidget);
        expect(find.byType(ProfileDisplayName), findsOneWidget);
        expect(find.byType(ProfileStatusIndicator), findsOneWidget);
        expect(find.byType(ProfileFavoriteButton), findsOneWidget);
        expect(find.byType(ProfilePopupMenuButton), findsOneWidget);
      });

      testWidgets('should handle different profile states correctly', (
        tester,
      ) async {
        // Test selected profile state
        const selectedState = ProfilesSelectedState({testUuid});
        await tester.pumpWidget(
          createMinimalTestWidget(profilesSelectedState: selectedState),
        );
        await tester.pump();
        expect(find.byType(ProfileViewMinimal), findsOneWidget);
        expect(find.byType(ProfileSelectBox), findsOneWidget);

        // Test favorite profile state
        const favoriteProfile = FavoriteProfile(uuid: testUuid);
        const favoritesState = FavoritesLoaded([favoriteProfile]);
        await tester.pumpWidget(
          createMinimalTestWidget(favoritesState: favoritesState),
        );
        await tester.pump();
        expect(find.byType(ProfileViewMinimal), findsOneWidget);
        expect(find.byType(ProfileFavoriteButton), findsOneWidget);
      });
    });

    group('ProfileViewSshStyle Widget Tests', () {
      Widget createSshStyleTestWidget({
        ProfileState? profileState,
        ProfilesSelectedState? profilesSelectedState,
        FavoritesState? favoritesState,
      }) {
        // Setup the bloc state mocks
        when(mockProfileBloc.state).thenReturn(
          profileState ?? ProfileLoaded(testUuid, profile: testProfile),
        );
        when(
          mockProfilesSelectedCubit.state,
        ).thenReturn(profilesSelectedState ?? const ProfilesSelectedState({}));
        when(
          mockFavoriteBloc.state,
        ).thenReturn(favoritesState ?? const FavoritesInitial());

        // Setup the stream mocks
        when(mockProfileBloc.stream).thenAnswer(
          (_) => Stream.value(
            profileState ?? ProfileLoaded(testUuid, profile: testProfile),
          ),
        );
        when(mockProfilesSelectedCubit.stream).thenAnswer(
          (_) => Stream.value(
            profilesSelectedState ?? const ProfilesSelectedState({}),
          ),
        );
        when(mockFavoriteBloc.stream).thenAnswer(
          (_) => Stream.value(favoritesState ?? const FavoritesInitial()),
        );

        return MaterialApp(
          navigatorKey: App.navState,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ProfileBloc>.value(value: mockProfileBloc),
                BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
                BlocProvider<ProfilesSelectedCubit>.value(
                  value: mockProfilesSelectedCubit,
                ),
                BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
                BlocProvider<ProfileColumnsCubit>(
                  create: (_) => ProfileColumnsCubit(),
                ),
              ],
              child: const ProfileViewSshStyle(),
            ),
          ),
        );
      }

      testWidgets('should render without ProviderNotFoundException', (
        tester,
      ) async {
        await tester.pumpWidget(createSshStyleTestWidget());
        await tester.pump();

        expect(find.byType(ProfileViewSshStyle), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });

      testWidgets('should display all expected child widgets', (tester) async {
        await tester.pumpWidget(createSshStyleTestWidget());
        await tester.pump();

        // Check for presence of key widgets within ProfileViewSshStyle
        expect(find.byType(ProfileSelectBox), findsOneWidget);
        expect(find.byType(ProfileDisplayName), findsOneWidget);
        expect(find.byType(ProfileDeviceName), findsOneWidget);
        expect(find.byType(ProfileServiceView), findsOneWidget);
        expect(find.byType(ProfileStatusIndicator), findsOneWidget);
        expect(find.byType(ProfileFavoriteButton), findsOneWidget);
        expect(find.byType(ProfilePopupMenuButton), findsOneWidget);
      });

      testWidgets('should handle selected profile state', (tester) async {
        // Test selected and favorite profile states
        const selectedState = ProfilesSelectedState({testUuid});
        await tester.pumpWidget(
          createSshStyleTestWidget(profilesSelectedState: selectedState),
        );
        await tester.pump();
        expect(find.byType(ProfileViewSshStyle), findsOneWidget);
        expect(find.byType(ProfileSelectBox), findsOneWidget);

        const favoriteProfile = FavoriteProfile(uuid: testUuid);
        const favoritesState = FavoritesLoaded([favoriteProfile]);
        await tester.pumpWidget(
          createSshStyleTestWidget(favoritesState: favoritesState),
        );
        await tester.pump();
        expect(find.byType(ProfileViewSshStyle), findsOneWidget);
        expect(find.byType(ProfileFavoriteButton), findsOneWidget);
      });
    });
  });
}
