import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../favorite/bloc/favorite_bloc_test.mocks.dart';
import '../profile/bloc/profile_bloc_test.mocks.dart';

/// Records the profile states the tray is reloaded with, and touches no
/// platform tray.
class _RecordingTrayCubit extends TrayCubit {
  final reloadedWith = <ProfileState>[];
  var reloads = 0;

  @override
  Future<void> initialize({AppLocalizations? localizations}) async {}

  @override
  Future<void> reloadIcon() async {}

  @override
  Future<void> reload({
    AppLocalizations? localizations,
    FavoritesState? favoriteState,
    ProfileListState? profileListState,
    ProfilesRunningState? profilesRunningState,
    OnboardingState? onboardingState,
    ProfileState? profileState,
  }) async {
    reloads++;
    if (profileState != null) reloadedWith.add(profileState);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uuid = 'profile-uuid';
  final profile = Profile(
    uuid,
    displayName: 'Office desktop',
    sshnpdAtsign: '@device'.toAtsign(),
    deviceName: 'desktop',
    remotePort: 3389,
    localPort: 0,
    relayAtsign: '@relay'.toAtsign(),
  );

  late MockProfileRepository repository;
  late _RecordingTrayCubit trayCubit;
  late ProfileListBloc listBloc;
  late ProfileCacheCubit cache;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          (_) async => null,
        );
    repository = MockProfileRepository();
    when(
      repository.getProfile(uuid, useCache: true),
    ).thenAnswer((_) async => profile);
    trayCubit = _RecordingTrayCubit();
    listBloc = ProfileListBloc(repository);
    cache = ProfileCacheCubit(repository);
    addTearDown(trayCubit.close);
    addTearDown(listBloc.close);
    addTearDown(cache.close);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  Future<void> pumpTrayManager(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
          BlocProvider<EnableLoggingCubit>(create: (_) => EnableLoggingCubit()),
          BlocProvider<TrayCubit>.value(value: trayCubit),
          BlocProvider<ProfileListBloc>.value(value: listBloc),
          BlocProvider<ProfileCacheCubit>.value(value: cache),
          BlocProvider<FavoriteBloc>(
            create: (_) => FavoriteBloc(MockFavoriteRepository()),
          ),
          BlocProvider<ProfilesRunningCubit>(
            create: (_) => ProfilesRunningCubit(),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(const SettingsRepository()),
          ),
        ],
        child: TrayManager(
          locale: const Locale('en'),
          child: MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// Lets the blocs' streams and the widget tree settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('Given the tray manager with a profile in the profile list', () {
    testWidgets('when that profile\'s state changes, then the tray is reloaded '
        'with it', (tester) async {
      final bloc = cache.getProfileBloc(uuid);
      await pumpTrayManager(tester);
      listBloc.add(const ProfileListUpdateEvent([uuid]));
      await settle(tester);
      expect(
        trayCubit.reloads,
        greaterThan(0),
        reason:
            'the profile list loading must reload the tray, or the test '
            'cannot see reloads at all',
      );

      bloc.add(const ProfileLoadEvent());
      await settle(tester);
      expect(
        bloc.state,
        isA<ProfileLoaded>(),
        reason: 'the test must observe a state change',
      );

      expect(
        trayCubit.reloadedWith.whereType<ProfileLoaded>(),
        isNotEmpty,
        reason:
            'the tray shows each favourite profile\'s name and status, so it '
            'must reload when a profile\'s state changes',
      );
    });

    testWidgets('when the profile leaves the profile list, then its cached '
        'bloc stays open', (tester) async {
      final bloc = cache.getProfileBloc(uuid);
      listBloc.add(const ProfileListUpdateEvent([uuid]));
      await pumpTrayManager(tester);
      await settle(tester);

      listBloc.add(const ProfileListUpdateEvent([]));
      await settle(tester);
      expect(
        (listBloc.state as ProfileListLoaded).profiles,
        isEmpty,
        reason: 'the test must observe the profile leaving the list',
      );

      expect(
        bloc.isClosed,
        isFalse,
        reason:
            'the profile cache owns its blocs and still hands this one out, '
            'so the tray must not close it',
      );
      expect(cache.getProfileBloc(uuid), same(bloc));
    });
  });

  group('Given the tray manager listening to window events', () {
    testWidgets('when it is disposed, then it no longer listens to them', (
      tester,
    ) async {
      await pumpTrayManager(tester);
      final trayManagerState = tester.state(find.byType(TrayManager));
      expect(
        windowManager.listeners,
        contains(trayManagerState),
        reason: 'the test must start with the tray manager listening',
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        windowManager.listeners,
        isNot(contains(trayManagerState)),
        reason: 'a disposed tray manager must not listen to window events',
      );
    });
  });
}
