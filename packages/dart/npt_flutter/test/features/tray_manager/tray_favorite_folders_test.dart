import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/onboarding.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/features/tray_manager/cubit/tray_cubit.dart';
import 'package:npt_flutter/features/tray_manager/widgets/tray_manager.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/profile_status.dart';
import 'package:tray_manager/tray_manager.dart' hide TrayManager;

class FakeProfileRepository extends Fake implements ProfileRepository {
  final Map<String, Profile> profiles;
  FakeProfileRepository(this.profiles);

  @override
  Future<Profile?> getProfile(String uuid, {bool useCache = true}) async =>
      profiles[uuid];
}

class FakeFavoriteRepository extends Fake implements FavoriteRepository {}

class FakeSettingsRepository extends Fake implements SettingsRepository {}

class FakeProfileFolderRepository extends Fake
    implements ProfileFolderRepository {
  @override
  void stopWatching() {}
}

class RecordingProfileBloc extends ProfileBloc {
  final List<ProfileEvent> events = <ProfileEvent>[];

  RecordingProfileBloc(ProfileRepository repo, ProfileState initial)
    : super(repo, initial.uuid) {
    emit(initial);
  }

  @override
  void add(ProfileEvent event) => events.add(event);

  void setState(ProfileState state) => emit(state);
}

class FakeProfileCache extends ProfileCacheCubit {
  final Map<String, RecordingProfileBloc> blocs;

  FakeProfileCache(super.repo, this.blocs);

  @override
  ProfileBloc getProfileBloc(String uuid) => blocs[uuid]!;
}

class RecordingStartQueue extends ProfileStartQueueCubit {
  final List<List<String>> added = <List<String>>[];
  final List<List<String>> removed = <List<String>>[];

  RecordingStartQueue(super.cache);

  @override
  void add(Iterable<String> uuids) => added.add(uuids.toList());

  @override
  void remove(Iterable<String> uuids) => removed.add(uuids.toList());

  void setWaiting(List<String> uuids) => emit(ProfileStartQueueState(uuids));
}

class IgnoringTrayListener with TrayListener {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppLocalizations strings = AppLocalizationsEn();
  const MethodChannel trayChannel = MethodChannel('tray_manager');
  const MethodChannel windowChannel = MethodChannel('window_manager');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const String webUuid = 'uuid-web';
  const String dbUuid = 'uuid-db';
  const String cacheUuid = 'uuid-cache';
  const String goneUuid = 'uuid-gone';
  const Map<String, String> defaultNames = <String, String>{
    webUuid: 'Web',
    dbUuid: 'Database',
    cacheUuid: 'Cache',
  };

  /// "Cache" is left out of Start all, "gone" is not a loaded connection.
  const ProfileFolder servers = ProfileFolder(
    uuid: 'f-servers',
    name: 'Servers',
    favorite: true,
    profileIds: <String>[webUuid, dbUuid, cacheUuid, goneUuid],
    skippedByStartAll: <String>[cacheUuid],
  );

  late List<MethodCall> trayCalls;
  late Map<String, RecordingProfileBloc> profileBlocs;
  late ProfileListBloc listBloc;
  late FavoriteBloc favoriteBloc;
  late ProfileFolderBloc folderBloc;
  late ProfilesRunningCubit runningCubit;
  late RecordingStartQueue startQueue;
  late TrayCubit tray;

  setUp(() {
    trayCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(trayChannel, (MethodCall call) async {
      trayCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(
      windowChannel,
      (MethodCall call) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(trayChannel, null);
      messenger.setMockMethodCallHandler(windowChannel, null);
    });
  });

  /// The real blocs must be created inside the test body so that their stream
  /// subscriptions live in the FakeAsync zone driven by [WidgetTester.pump].
  /// With [listening] the tray also reloads itself on state changes, as in the
  /// app; otherwise the test calls [TrayCubit.reload] itself.
  Future<void> pumpTray(
    WidgetTester tester, {
    Map<String, String> loaded = defaultNames,
    List<String> favorites = const <String>[],
    List<ProfileFolder>? folders,
    bool listening = false,
  }) async {
    final Map<String, Profile> profiles = <String, Profile>{
      for (final MapEntry<String, String> entry in loaded.entries)
        entry.key: Profile(
          entry.key,
          displayName: entry.value,
          deviceName: 'device',
          remotePort: 22,
          localPort: 2222,
        ),
    };
    final FakeProfileRepository repo = FakeProfileRepository(profiles);
    profileBlocs = <String, RecordingProfileBloc>{
      for (final Profile profile in profiles.values)
        profile.uuid: RecordingProfileBloc(
          repo,
          ProfileLoaded(profile.uuid, profile: profile),
        ),
    };
    final FakeProfileCache cache = FakeProfileCache(repo, profileBlocs);

    listBloc = ProfileListBloc(repo)
      ..emit(ProfileListLoaded(profiles: loaded.keys.toList()));
    favoriteBloc = FavoriteBloc(FakeFavoriteRepository())
      ..emit(
        FavoritesLoaded(
          favorites.map((String uuid) => FavoriteProfile(uuid: uuid)).toList(),
        ),
      );
    folderBloc = ProfileFolderBloc(FakeProfileFolderRepository());
    if (folders != null) {
      folderBloc.emit(
        ProfileFoldersLoaded(ProfileFolderData(folders: folders)),
      );
    }
    runningCubit = ProfilesRunningCubit();
    startQueue = RecordingStartQueue(cache);
    tray = TrayCubit();
    final SettingsBloc settingsBloc = SettingsBloc(FakeSettingsRepository());
    final EnableLoggingCubit loggingCubit = EnableLoggingCubit()..disable();
    final LogsCubit logsCubit = LogsCubit();
    final OnboardingCubit onboardingCubit = OnboardingCubit();
    addTearDown(() async {
      await tray.close();
      await startQueue.close();
      await runningCubit.close();
      await folderBloc.close();
      await favoriteBloc.close();
      await listBloc.close();
      await settingsBloc.close();
      await onboardingCubit.close();
      await logsCubit.close();
      await loggingCubit.close();
      for (final RecordingProfileBloc bloc in profileBlocs.values) {
        await bloc.close();
      }
    });

    if (!listening) {
      // The plugin only reports menu clicks while something listens, and it
      // calls each menu item once per listener, so the tray widget must be the
      // only one when it is there.
      final IgnoringTrayListener listener = IgnoringTrayListener();
      trayManager.addListener(listener);
      addTearDown(() => trayManager.removeListener(listener));
    }

    final Widget app = MaterialApp(
      navigatorKey: App.navState,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SizedBox(),
    );
    await tester.pumpWidget(
      RepositoryProvider<ProfileRepository>.value(
        value: repo,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<EnableLoggingCubit>.value(value: loggingCubit),
            BlocProvider<LogsCubit>.value(value: logsCubit),
            BlocProvider<OnboardingCubit>.value(value: onboardingCubit),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<ProfileListBloc>.value(value: listBloc),
            BlocProvider<FavoriteBloc>.value(value: favoriteBloc),
            BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
            BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
            BlocProvider<ProfileCacheCubit>.value(value: cache),
            BlocProvider<ProfileStartQueueCubit>.value(value: startQueue),
            BlocProvider<TrayCubit>.value(value: tray),
          ],
          child: listening
              ? TrayManager(locale: const Locale('en'), child: app)
              : app,
        ),
      ),
    );
  }

  /// Marks [uuid] as connected, the way the app does once a start succeeds.
  void connect(String uuid) {
    final ProfileLoadedState current =
        profileBlocs[uuid]!.state as ProfileLoadedState;
    profileBlocs[uuid]!.setState(
      ProfileStarted(uuid, profile: current.profile),
    );
    runningCubit.prepare(uuid);
  }

  /// Lets the reloads the tray started on its own run to the end.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  List<MethodCall> menuCalls() => trayCalls
      .where((MethodCall call) => call.method == 'setContextMenu')
      .toList();

  List<Map<Object?, Object?>> menuItems() {
    final Map<Object?, Object?> menu =
        (menuCalls().last.arguments as Map<Object?, Object?>)['menu']
            as Map<Object?, Object?>;
    return (menu['items'] as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .toList();
  }

  List<String> menuLabels() => menuItems()
      .map(
        (Map<Object?, Object?> item) =>
            item['type'] == 'separator' ? '---' : item['label']! as String,
      )
      .toList();

  Future<void> tapMenuItem(String label) async {
    final Map<Object?, Object?> item = menuItems().firstWhere(
      (Map<Object?, Object?> item) => item['label'] == label,
    );
    await messenger.handlePlatformMessage(
      trayChannel.name,
      trayChannel.codec.encodeMethodCall(
        MethodCall('onTrayMenuItemClick', <String, Object?>{'id': item['id']}),
      ),
      (_) {},
    );
  }

  Iterable<ProfileEvent> sentEvents() =>
      profileBlocs.values.expand((RecordingProfileBloc bloc) => bloc.events);

  final String off = ProfileStatus.off.emoji;
  final String on = ProfileStatus.on.emoji;

  group('menu contents', () {
    testWidgets(
      'lists favorite folders first, sorted by name with accents folded',
      (WidgetTester tester) async {
        await pumpTray(
          tester,
          loaded: const <String, String>{
            webUuid: 'Ångström link',
            dbUuid: 'Beta',
            cacheUuid: 'Aardvark',
          },
          favorites: const <String>[webUuid, dbUuid, cacheUuid],
          folders: const <ProfileFolder>[
            ProfileFolder(uuid: 'f-1', name: 'Zebra', favorite: true),
            ProfileFolder(uuid: 'f-2', name: 'Écran', favorite: true),
            ProfileFolder(uuid: 'f-3', name: 'alpha', favorite: true),
            ProfileFolder(uuid: 'f-4', name: 'Hidden'),
          ],
        );
        await tray.reload();

        expect(menuLabels(), <String>[
          '$off alpha (0/0)',
          '$off Écran (0/0)',
          '$off Zebra (0/0)',
          '$off Aardvark',
          '$off Ångström link',
          '$off Beta',
          '---',
          strings.showWindow,
          strings.quit,
        ]);
      },
    );

    testWidgets('lists only favorite connections until folders have loaded', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, favorites: const <String>[webUuid]);
      await tray.reload();

      expect(menuLabels(), <String>[
        '$off Web',
        '---',
        strings.showWindow,
        strings.quit,
      ]);
    });

    testWidgets('keeps the basic menu until favorites have loaded', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      favoriteBloc.emit(const FavoritesLoading());
      await tray.reload();

      expect(menuLabels(), <String>[strings.showWindow, strings.quit]);
    });

    testWidgets('keeps the basic menu until connections have loaded', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      listBloc.emit(const ProfileListLoading());
      await tray.reload();

      expect(menuLabels(), <String>[strings.showWindow, strings.quit]);
    });

    testWidgets('uses the folder state it is given over the current one', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      await tray.reload(
        profileFolderState: const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(uuid: 'f-servers', name: 'Renamed', favorite: true),
            ],
          ),
        ),
      );

      expect(menuLabels().first, '$off Renamed (0/0)');
    });
  });

  group('folder label', () {
    testWidgets('shows how many of the startable connections are running', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      await tray.reload();

      expect(menuLabels().first, '$off Servers (0/2)');
    });

    testWidgets('shows a running startable connection in the count', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      connect(webUuid);
      await tray.reload();

      expect(menuLabels().first, '$on Servers (1/2)');
    });

    testWidgets('shows a running skipped connection as on but not counted', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      connect(cacheUuid);
      await tray.reload();

      expect(menuLabels().first, '$on Servers (0/2)');
    });
  });

  group('clicking a folder', () {
    testWidgets('starts only its startable connections when none are active', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      await tray.reload();

      await tapMenuItem('$off Servers (0/2)');

      expect(startQueue.added, <List<String>>[
        <String>[webUuid, dbUuid],
      ]);
      expect(startQueue.removed, isEmpty);
      expect(sentEvents(), isEmpty);
    });

    testWidgets('stops all its connections when one is running', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      connect(webUuid);
      await tray.reload();

      await tapMenuItem('$on Servers (1/2)');

      expect(startQueue.added, isEmpty);
      expect(startQueue.removed, <List<String>>[
        <String>[webUuid, dbUuid, cacheUuid],
      ]);
      expect(profileBlocs[webUuid]!.events.single, isA<ProfileStopEvent>());
      expect(profileBlocs[dbUuid]!.events, isEmpty);
      expect(profileBlocs[cacheUuid]!.events, isEmpty);
    });

    testWidgets(
      'stops when only a connection skipped by Start all is running',
      (WidgetTester tester) async {
        await pumpTray(tester, folders: const <ProfileFolder>[servers]);
        connect(cacheUuid);
        await tray.reload();

        await tapMenuItem('$on Servers (0/2)');

        expect(startQueue.added, isEmpty);
        expect(startQueue.removed, <List<String>>[
          <String>[webUuid, dbUuid, cacheUuid],
        ]);
        expect(profileBlocs[cacheUuid]!.events.single, isA<ProfileStopEvent>());
      },
    );

    testWidgets('stops instead of starting when a connection is waiting', (
      WidgetTester tester,
    ) async {
      await pumpTray(tester, folders: const <ProfileFolder>[servers]);
      startQueue.setWaiting(<String>[dbUuid]);
      await tray.reload();

      await tapMenuItem('$off Servers (0/2)');

      expect(startQueue.added, isEmpty);
      expect(startQueue.removed, <List<String>>[
        <String>[webUuid, dbUuid, cacheUuid],
      ]);
      expect(sentEvents(), isEmpty);
    });
  });

  group('while the tray listens for changes', () {
    testWidgets('follows a folder being favorited, renamed and unfavorited', (
      WidgetTester tester,
    ) async {
      const ProfileFolder plain = ProfileFolder(
        uuid: 'f-1',
        name: 'Servers',
        profileIds: <String>[webUuid],
      );
      await pumpTray(tester, listening: true);

      folderBloc.emit(
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[plain.copyWith(favorite: true)],
          ),
        ),
      );
      await settle(tester);
      expect(menuLabels().first, '$off Servers (0/1)');

      folderBloc.emit(
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              plain.copyWith(favorite: true, name: 'Machines'),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(menuLabels().first, '$off Machines (0/1)');

      folderBloc.emit(
        const ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[plain]),
        ),
      );
      await settle(tester);
      expect(menuLabels(), <String>['---', strings.showWindow, strings.quit]);
    });

    testWidgets('rebuilds the menu when only the start queue changes', (
      WidgetTester tester,
    ) async {
      await pumpTray(
        tester,
        folders: const <ProfileFolder>[servers],
        listening: true,
      );
      await tray.reload();
      final int menusBefore = menuCalls().length;

      startQueue.setWaiting(<String>[dbUuid]);
      await settle(tester);
      expect(menuCalls().length, greaterThan(menusBefore));

      await tapMenuItem('$off Servers (0/2)');

      expect(startQueue.added, isEmpty);
      expect(startQueue.removed, <List<String>>[
        <String>[webUuid, dbUuid, cacheUuid],
      ]);
      expect(sentEvents(), isEmpty);
    });

    testWidgets('starts again once nothing in the folder is waiting', (
      WidgetTester tester,
    ) async {
      await pumpTray(
        tester,
        folders: const <ProfileFolder>[servers],
        listening: true,
      );
      startQueue.setWaiting(<String>[dbUuid]);
      await settle(tester);

      startQueue.setWaiting(const <String>[]);
      await settle(tester);
      await tapMenuItem('$off Servers (0/2)');

      expect(startQueue.added, <List<String>>[
        <String>[webUuid, dbUuid],
      ]);
      expect(startQueue.removed, isEmpty);
    });

    testWidgets('updates the running count when a connection starts', (
      WidgetTester tester,
    ) async {
      await pumpTray(
        tester,
        folders: const <ProfileFolder>[servers],
        listening: true,
      );
      connect(webUuid);
      await settle(tester);

      expect(menuLabels().first, '$on Servers (1/2)');
    });
  });
}
