import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/cubit/backup_key_cubit.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/language.dart';

import 'profile_list_view_test.mocks.dart';

/// The cubits log through the navigator context, which prints every change.
class _SilentLogsCubit extends LogsCubit {
  @override
  void log(Loggable loggable) {}
}

class _FakeProfileFolderRepository extends ProfileFolderRepository {
  @override
  Future<ProfileFolderData?> getProfileFolders() async => null;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppLocalizations strings = AppLocalizationsEn();

  const String sshUuid = 'uuid-ssh';
  const String rdpUuid = 'uuid-rdp';
  const String vncUuid = 'uuid-vnc';
  const String noneUuid = 'uuid-none';
  const String extraUuid = 'uuid-extra';
  const List<String> allUuids = <String>[
    sshUuid,
    rdpUuid,
    vncUuid,
    noneUuid,
    extraUuid,
  ];

  const Map<String, String> displayNames = <String, String>{
    sshUuid: 'Alpha',
    rdpUuid: 'Beta',
    vncUuid: 'Gamma',
    noneUuid: 'Delta',
    extraUuid: 'Zeta',
  };

  Profile buildProfile(String uuid) => Profile(
    uuid,
    displayName: displayNames[uuid]!,
    sshnpdAtsign: '@device'.toAtsign(),
    deviceName: 'device',
    remotePort: 22,
    localPort: 2222,
    connectUriProtocol: '',
  );

  final Settings testSettings = Settings(
    relayAtsign: '@rv_am'.toAtsign(),
    overrideRelay: false,
    viewLayout: PreferredViewLayout.minimal,
    language: Language.english,
  );

  const ProfileFolder serversFolder = ProfileFolder(
    uuid: 'g-servers',
    name: 'Servers',
    profileIds: <String>[sshUuid, rdpUuid],
  );
  const ProfileFolder desktopsFolder = ProfileFolder(
    uuid: 'g-desktops',
    name: 'Desktops',
    profileIds: <String>[vncUuid],
  );

  /// Alpha and Beta in Servers, Gamma in Desktops, Delta and Zeta unfiled.
  const ProfileFolderData openFolders = ProfileFolderData(
    folders: <ProfileFolder>[serversFolder, desktopsFolder],
  );
  final ProfileFolderData serversCollapsed = openFolders.withCollapsed(
    serversFolder.uuid,
    true,
  );
  final ProfileFolderData unfiledCollapsed = openFolders.copyWith(
    unfiledCollapsed: true,
  );

  late MockProfileCacheCubit mockCache;
  late MockProfileListBloc mockListBloc;
  late MockSettingsBloc mockSettingsBloc;
  late MockFavoriteBloc mockFavoriteBloc;
  late MockSyncCubit mockSyncCubit;
  late MockBackupKeyCubit mockBackupKeyCubit;
  late MockOnboardingCubit mockOnboardingCubit;
  late ProfilesSelectedCubit selectedCubit;
  late ProfileFolderBloc folderBloc;

  setUp(() {
    provideDummy<ProfileState>(const ProfileInitial('dummy'));
    provideDummy<SettingsState>(const SettingsInitial());
    provideDummy<FavoritesState>(const FavoritesInitial());
    provideDummy<ProfileListState>(const ProfileListInitial());
    provideDummy<OnboardingState>(
      OnboardingState(
        atsign: '@test'.toAtsign(),
        status: OnboardingStatus.onboarded,
        rootDomain: 'root.atsign.org',
      ),
    );

    mockCache = MockProfileCacheCubit();
    for (final String uuid in allUuids) {
      final MockProfileBloc bloc = MockProfileBloc();
      final ProfileState state = ProfileLoaded(
        uuid,
        profile: buildProfile(uuid),
      );
      when(bloc.uuid).thenReturn(uuid);
      when(bloc.state).thenReturn(state);
      when(bloc.stream).thenAnswer((_) => Stream<ProfileState>.value(state));
      when(mockCache.getProfileBloc(uuid)).thenReturn(bloc);
    }

    mockListBloc = MockProfileListBloc();
    when(
      mockListBloc.state,
    ).thenReturn(const ProfileListLoaded(profiles: allUuids));
    when(mockListBloc.stream).thenAnswer(
      (_) => Stream<ProfileListState>.value(
        const ProfileListLoaded(profiles: allUuids),
      ),
    );

    mockSettingsBloc = MockSettingsBloc();
    when(
      mockSettingsBloc.state,
    ).thenReturn(SettingsLoaded(settings: testSettings));
    when(mockSettingsBloc.stream).thenAnswer(
      (_) =>
          Stream<SettingsState>.value(SettingsLoaded(settings: testSettings)),
    );

    mockFavoriteBloc = MockFavoriteBloc();
    when(mockFavoriteBloc.state).thenReturn(const FavoritesLoaded([]));
    when(mockFavoriteBloc.stream).thenAnswer(
      (_) => Stream<FavoritesState>.value(const FavoritesLoaded([])),
    );

    mockSyncCubit = MockSyncCubit();
    when(mockSyncCubit.state).thenReturn(true);
    when(mockSyncCubit.stream).thenAnswer((_) => const Stream<bool>.empty());

    mockBackupKeyCubit = MockBackupKeyCubit();
    when(mockBackupKeyCubit.state).thenReturn(false);
    when(
      mockBackupKeyCubit.stream,
    ).thenAnswer((_) => Stream<bool>.value(false));
    when(
      mockBackupKeyCubit.getBackupKeyStatus(),
    ).thenAnswer((_) => Future<bool>.value(true));

    mockOnboardingCubit = MockOnboardingCubit();
    final OnboardingState onboarded = OnboardingState(
      atsign: '@test'.toAtsign(),
      status: OnboardingStatus.onboarded,
      rootDomain: 'root.atsign.org',
    );
    when(mockOnboardingCubit.state).thenReturn(onboarded);
    when(
      mockOnboardingCubit.stream,
    ).thenAnswer((_) => Stream<OnboardingState>.value(onboarded));
  });

  Future<void> pumpList(
    WidgetTester tester,
    ProfileFolderData data, {
    bool synced = true,
  }) async {
    selectedCubit = ProfilesSelectedCubit();
    folderBloc = ProfileFolderBloc(_FakeProfileFolderRepository());
    folderBloc.emit(ProfileFoldersLoaded(data, synced: synced));
    addTearDown(() async {
      await selectedCubit.close();
      await folderBloc.close();
    });

    tester.view.physicalSize = const Size(1053, 691);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<LogsCubit>(create: (_) => _SilentLogsCubit()),
          BlocProvider<ProfileListBloc>.value(value: mockListBloc),
          BlocProvider<ProfileCacheCubit>.value(value: mockCache),
          BlocProvider<ProfileStartQueueCubit>(
            create: (_) => ProfileStartQueueCubit(mockCache),
          ),
          BlocProvider<ProfilesRunningCubit>(
            create: (_) => ProfilesRunningCubit(),
          ),
          BlocProvider<SyncCubit>.value(value: mockSyncCubit),
          BlocProvider<BackupKeyCubit>.value(value: mockBackupKeyCubit),
          BlocProvider<OnboardingCubit>.value(value: mockOnboardingCubit),
          BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
          BlocProvider<ProfilesSelectedCubit>.value(value: selectedCubit),
          BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
          BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
        ],
        child: MaterialApp(
          navigatorKey: App.navState,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfileListView()),
        ),
      ),
    );
    await tester.pump();
  }

  Finder header(String id) =>
      find.byKey(ValueKey<String>('ProfileFolderSectionHeader-$id'));
  Finder row(String uuid) =>
      find.byKey(ValueKey<String>('ProfileListRow-$uuid'));
  Finder toggle(String sectionId, String tooltip) => find.descendant(
    of: header(sectionId),
    matching: find.byWidgetPredicate(
      (Widget w) => w is IconButton && w.tooltip == tooltip,
    ),
  );

  Future<void> collapse(WidgetTester tester, String sectionId) async {
    await tester.tap(toggle(sectionId, strings.folderCollapse));
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester, String sectionId) async {
    await tester.tap(toggle(sectionId, strings.folderExpand));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, Iterable<String> uuids) async {
    selectedCubit.selectOnly(uuids);
    await tester.pump();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('ProfileListSearchField')),
      query,
    );
    await tester.pumpAndSettle();
  }

  Future<void> clearSearch(WidgetTester tester) async {
    await tester.tap(find.byTooltip(strings.profileSearchClear));
    await tester.pumpAndSettle();
  }

  group('collapsing a folder', () {
    testWidgets('deselects the connections it hides', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, rdpUuid]);

      await collapse(tester, serversFolder.uuid);

      expect(row(sshUuid), findsNothing);
      expect(selectedCubit.state.selected, isEmpty);
    });

    testWidgets('keeps the selected connections in folders that stay open', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, rdpUuid, vncUuid, noneUuid]);

      await collapse(tester, serversFolder.uuid);

      expect(selectedCubit.state.selected, <String>{vncUuid, noneUuid});
    });

    testWidgets('deselects only the hidden ones among a folder\'s members', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, vncUuid]);

      await collapse(tester, desktopsFolder.uuid);

      expect(selectedCubit.state.selected, <String>{sshUuid});
    });

    testWidgets('deselects the connections of a collapsed No folder section', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, noneUuid, extraUuid]);

      await collapse(tester, ProfileFolderListView.unfiledSectionId);

      expect(row(noneUuid), findsNothing);
      expect(selectedCubit.state.selected, <String>{sshUuid});
    });

    testWidgets('before the folders have synced deselects as well', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders, synced: false);
      await select(tester, <String>[sshUuid, vncUuid]);

      await collapse(tester, serversFolder.uuid);

      expect(row(sshUuid), findsNothing);
      expect(selectedCubit.state.selected, <String>{vncUuid});
    });

    testWidgets('then opening it again selects nothing back', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, vncUuid]);
      await collapse(tester, serversFolder.uuid);

      await expand(tester, serversFolder.uuid);

      expect(row(sshUuid), findsOneWidget);
      expect(selectedCubit.state.selected, <String>{vncUuid});
    });
  });

  group('a collapse arriving from a sync', () {
    testWidgets('deselects the connections it hides', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, rdpUuid, vncUuid]);

      folderBloc.emit(ProfileFoldersLoaded(serversCollapsed));
      await tester.pumpAndSettle();

      expect(row(sshUuid), findsNothing);
      expect(selectedCubit.state.selected, <String>{vncUuid});
    });

    testWidgets('of the No folder section deselects its connections', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, noneUuid]);

      folderBloc.emit(ProfileFoldersLoaded(unfiledCollapsed));
      await tester.pumpAndSettle();

      expect(row(noneUuid), findsNothing);
      expect(selectedCubit.state.selected, <String>{sshUuid});
    });

    testWidgets('that catches the folders up keeps rows in open folders', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders, synced: false);
      await select(tester, <String>[sshUuid, vncUuid, noneUuid]);

      folderBloc.emit(ProfileFoldersLoaded(serversCollapsed));
      await tester.pumpAndSettle();

      expect(selectedCubit.state.selected, <String>{vncUuid, noneUuid});
    });

    testWidgets('that opens a folder leaves the selection alone', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, serversCollapsed);
      await select(tester, <String>[vncUuid, noneUuid]);

      folderBloc.emit(const ProfileFoldersLoaded(openFolders));
      await tester.pumpAndSettle();

      expect(row(sshUuid), findsOneWidget);
      expect(selectedCubit.state.selected, <String>{vncUuid, noneUuid});
    });

    testWidgets('of a No folder section in a list without folders hides '
        'nothing', (WidgetTester tester) async {
      await pumpList(tester, const ProfileFolderData());
      await select(tester, <String>[sshUuid, noneUuid]);

      folderBloc.emit(
        const ProfileFoldersLoaded(ProfileFolderData(unfiledCollapsed: true)),
      );
      await tester.pumpAndSettle();

      expect(row(sshUuid), findsOneWidget);
      expect(selectedCubit.state.selected, <String>{sshUuid, noneUuid});
    });
  });

  group('searching', () {
    testWidgets('deselects the selected connections the search hides', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, openFolders);
      await select(tester, <String>[sshUuid, rdpUuid, vncUuid]);

      await search(tester, 'beta');

      expect(selectedCubit.state.selected, <String>{rdpUuid});
    });

    testWidgets('keeps a selected connection that a collapsed folder hides '
        'until the search is cleared', (WidgetTester tester) async {
      await pumpList(tester, serversCollapsed);
      expect(row(sshUuid), findsNothing);

      await search(tester, 'a');
      expect(row(sshUuid), findsOneWidget);
      await select(tester, <String>[sshUuid, vncUuid]);

      await search(tester, 'al');
      expect(selectedCubit.state.selected, <String>{sshUuid});

      await search(tester, 'alp');
      expect(selectedCubit.state.selected, <String>{sshUuid});

      await clearSearch(tester);

      expect(row(sshUuid), findsNothing);
      expect(selectedCubit.state.selected, isEmpty);
    });

    testWidgets(
      'clearing a search that showed a collapsed folder deselects only '
      'its connections',
      (WidgetTester tester) async {
        await pumpList(tester, serversCollapsed);
        await search(tester, 'a');
        expect(find.byType(ProfileListRow), findsNWidgets(5));
        await select(tester, <String>[sshUuid, rdpUuid, vncUuid, noneUuid]);

        await clearSearch(tester);

        expect(find.byType(ProfileListRow), findsNWidgets(3));
        expect(selectedCubit.state.selected, <String>{vncUuid, noneUuid});
      },
    );

    testWidgets('a collapse arriving while searching keeps the selection '
        'until the search is cleared', (WidgetTester tester) async {
      await pumpList(tester, openFolders);
      await search(tester, 'a');
      await select(tester, <String>[sshUuid, vncUuid]);

      folderBloc.emit(ProfileFoldersLoaded(serversCollapsed));
      await tester.pumpAndSettle();
      expect(selectedCubit.state.selected, <String>{sshUuid, vncUuid});

      await clearSearch(tester);

      expect(selectedCubit.state.selected, <String>{vncUuid});
    });
  });

  group('when the connection list is cleared', () {
    testWidgets('the search is cleared, so it does not filter the next '
        "atSign's connections", (WidgetTester tester) async {
      final StreamController<ProfileListState> lists =
          StreamController<ProfileListState>.broadcast();
      addTearDown(lists.close);
      ProfileListState list = const ProfileListLoaded(profiles: allUuids);
      when(mockListBloc.state).thenAnswer((_) => list);
      when(mockListBloc.stream).thenAnswer((_) => lists.stream);
      await pumpList(tester, openFolders);
      await search(tester, 'al');
      expect(find.byType(ProfileListRow), findsOneWidget);
      ProfileListFilterCubit filter() => tester
          .element(find.byType(ProfileListSearchField))
          .read<ProfileListFilterCubit>();
      filter().sort(ProfileSortMode.nameDescending);

      list = const ProfileListInitial();
      lists.add(list);
      await tester.pump();
      list = const ProfileListLoaded(profiles: allUuids);
      lists.add(list);
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ProfileListSearchField')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byType(ProfileListRow), findsNWidgets(allUuids.length));
      expect(
        filter().state.sortMode,
        ProfileSortMode.manual,
        reason: "the next atSign's settings may fail to load",
      );
    });
  });
}
