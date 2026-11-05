import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/language.dart';

import '../../profile_list/view/profile_list_view_test.mocks.dart';

class FakeProfileFolderRepository extends ProfileFolderRepository {
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  @override
  Future<ProfileFolderData?> getProfileFolders() async => null;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    puts.add(data);
    return true;
  }
}

/// Keeps every event it is given, to tell "sent nothing" from "sent a no-op".
class RecordingProfileFolderBloc extends ProfileFolderBloc {
  final List<ProfileFolderEvent> events = <ProfileFolderEvent>[];

  RecordingProfileFolderBloc(super.repository);

  @override
  void onEvent(ProfileFolderEvent event) {
    events.add(event);
    super.onEvent(event);
  }
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
  const ProfileFolderData twoFolders = ProfileFolderData(
    folders: <ProfileFolder>[serversFolder, desktopsFolder],
  );

  late MockProfileCacheCubit mockCache;
  late Map<String, MockProfileBloc> profileBlocs;
  late MockSettingsBloc mockSettingsBloc;
  late MockProfileListBloc mockListBloc;
  late MockFavoriteBloc mockFavoriteBloc;
  late ProfilesSelectedCubit selectedCubit;
  late ProfilesRunningCubit runningCubit;
  late ProfileListFilterCubit filterCubit;
  late FakeProfileFolderRepository folderRepo;
  late RecordingProfileFolderBloc folderBloc;

  setUp(() {
    provideDummy<ProfileState>(const ProfileInitial('dummy'));
    provideDummy<SettingsState>(const SettingsInitial());
    provideDummy<FavoritesState>(const FavoritesInitial());
    provideDummy<ProfileListState>(const ProfileListInitial());

    mockCache = MockProfileCacheCubit();
    profileBlocs = <String, MockProfileBloc>{};
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
      profileBlocs[uuid] = bloc;
    }

    mockSettingsBloc = MockSettingsBloc();
    when(
      mockSettingsBloc.state,
    ).thenReturn(SettingsLoaded(settings: testSettings));
    when(mockSettingsBloc.stream).thenAnswer(
      (_) =>
          Stream<SettingsState>.value(SettingsLoaded(settings: testSettings)),
    );

    mockListBloc = MockProfileListBloc();
    when(
      mockListBloc.state,
    ).thenReturn(const ProfileListLoaded(profiles: allUuids));
    when(mockListBloc.stream).thenAnswer(
      (_) => Stream<ProfileListState>.value(
        const ProfileListLoaded(profiles: allUuids),
      ),
    );

    mockFavoriteBloc = MockFavoriteBloc();
    when(mockFavoriteBloc.state).thenReturn(const FavoritesLoaded([]));
    when(mockFavoriteBloc.stream).thenAnswer(
      (_) => Stream<FavoritesState>.value(const FavoritesLoaded([])),
    );
  });

  /// The real cubits are created here so their streams run in FakeAsync.
  void createRealBlocs() {
    selectedCubit = ProfilesSelectedCubit();
    runningCubit = ProfilesRunningCubit();
    filterCubit = ProfileListFilterCubit(mockCache);
    folderRepo = FakeProfileFolderRepository();
    folderBloc = RecordingProfileFolderBloc(folderRepo);
    addTearDown(() async {
      await selectedCubit.close();
      await runningCubit.close();
      await filterCubit.close();
      await folderBloc.close();
    });
  }

  Widget buildApp(WidgetTester tester, Widget child) {
    tester.view.physicalSize = const Size(1053, 691);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileCacheCubit>.value(value: mockCache),
        BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
        BlocProvider<ProfilesSelectedCubit>.value(value: selectedCubit),
        BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
        BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
        BlocProvider<ProfileStartQueueCubit>(
          create: (_) => ProfileStartQueueCubit(mockCache),
        ),
        BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
        BlocProvider<ProfileListBloc>.value(value: mockListBloc),
        BlocProvider<ProfileListFilterCubit>.value(value: filterCubit),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  Future<void> pumpListView(
    WidgetTester tester,
    ProfileFolderState state, {
    Widget? child,
  }) async {
    createRealBlocs();
    folderBloc.emit(state);
    await tester.pumpWidget(
      buildApp(tester, child ?? ProfileFolderListView(profiles: allUuids)),
    );
    await tester.pump();
  }

  Finder header(String id) =>
      find.byKey(ValueKey<String>('ProfileFolderSectionHeader-$id'));
  Finder row(String uuid) =>
      find.byKey(ValueKey<String>('ProfileListRow-$uuid'));
  Finder headerButton(String folderId, String tooltip) => find.descendant(
    of: header(folderId),
    matching: find.byWidgetPredicate(
      (Widget w) => w is IconButton && w.tooltip == tooltip,
    ),
  );
  bool isEnabled(WidgetTester tester, Finder button) =>
      tester.widget<IconButton>(button).onPressed != null;

  Finder menuButton(Finder within) => find.descendant(
    of: within,
    matching: find.byType(PopupMenuButton<PopupMenuEntry>),
  );
  Future<void> openMenu(WidgetTester tester, Finder within) async {
    await tester.tap(menuButton(within));
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
  }

  Map<String, bool> folderMenuEnabled(WidgetTester tester) {
    return <String, bool>{
      for (final String label in <String>[
        strings.folderAddConnection,
        strings.folderChooseStartAll,
        strings.folderRename,
        strings.folderMoveUp,
        strings.folderMoveDown,
        strings.folderDelete,
      ])
        label: tester
            .widget<PopupMenuItem<PopupMenuEntry>>(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(PopupMenuItem<PopupMenuEntry>),
              ),
            )
            .enabled,
    };
  }

  const Key gripKey = Key('ProfileDragHandle');
  final Finder createButton = find.byKey(
    const Key('ProfileFolderCreateButton'),
  );
  final Finder moveButton = find.byKey(const Key('ProfileFolderMoveButton'));
  const Key nameFieldKey = Key('ProfileFolderNameDialog-TextFormField');

  group('folders that have not synced with the atServer', () {
    const ProfileFoldersLoaded unsynced = ProfileFoldersLoaded(
      twoFolders,
      synced: false,
    );
    const ProfileFoldersLoaded synced = ProfileFoldersLoaded(twoFolders);

    testWidgets('are listed from the local copy at once', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);

      expect(header(serversFolder.uuid), findsOneWidget);
      expect(header(desktopsFolder.uuid), findsOneWidget);
      expect(header(ProfileFolderListView.unfiledSectionId), findsOneWidget);
      expect(find.byType(ProfileListRow), findsNWidgets(5));
    });

    testWidgets('have no drag grips and no reorderable list', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);

      expect(find.byKey(gripKey), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
    });

    testWidgets('have no drag grips in a list without folders either', (
      WidgetTester tester,
    ) async {
      await pumpListView(
        tester,
        const ProfileFoldersLoaded(ProfileFolderData(), synced: false),
      );

      expect(find.byType(ProfileFolderSectionHeader), findsNothing);
      expect(find.byType(ProfileListRow), findsNWidgets(5));
      expect(find.byKey(gripKey), findsNothing);
    });

    testWidgets('have no drag grips in a sorted list either', (
      WidgetTester tester,
    ) async {
      const ProfileFolderListView sorted = ProfileFolderListView(
        profiles: allUuids,
        reorderable: false,
        movable: true,
      );
      await pumpListView(tester, unsynced, child: sorted);
      expect(find.byKey(gripKey), findsNothing);

      folderBloc.emit(synced);
      await tester.pumpAndSettle();

      expect(find.byKey(gripKey), findsNWidgets(5));
      expect(
        find.descendant(
          of: header(serversFolder.uuid),
          matching: find.byKey(gripKey),
        ),
        findsNothing,
      );
    });

    testWidgets('keep the star disabled but still open and close folders', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);

      for (final ProfileFolder folder in twoFolders.folders) {
        expect(
          isEnabled(tester, headerButton(folder.uuid, strings.favoriteAdd)),
          isFalse,
          reason: '${folder.name} star',
        );
        expect(
          isEnabled(tester, headerButton(folder.uuid, strings.folderCollapse)),
          isTrue,
          reason: '${folder.name} collapse toggle',
        );
      }

      await tester.tap(
        headerButton(serversFolder.uuid, strings.folderCollapse),
      );
      await tester.pumpAndSettle();

      expect(row(sshUuid), findsNothing);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('disable every folder menu item', (WidgetTester tester) async {
      await pumpListView(tester, unsynced);

      for (final ProfileFolder folder in twoFolders.folders) {
        await openMenu(tester, header(folder.uuid));
        expect(folderMenuEnabled(tester), <String, bool>{
          strings.folderAddConnection: false,
          strings.folderChooseStartAll: false,
          strings.folderRename: false,
          strings.folderMoveUp: false,
          strings.folderMoveDown: false,
          strings.folderDelete: false,
        }, reason: folder.name);
        await closeMenu(tester);
      }
    });

    testWidgets('leave Move to folder out of the connection menu', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);

      await openMenu(tester, row(sshUuid));

      expect(find.text(strings.edit), findsOneWidget);
      expect(find.text(strings.duplicate), findsOneWidget);
      expect(find.text(strings.folderMoveToFolder), findsNothing);
    });

    testWidgets('keep Start all and Stop all working', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);

      final Finder start = headerButton(
        serversFolder.uuid,
        strings.folderStartAll,
      );
      final Finder stop = headerButton(
        serversFolder.uuid,
        strings.folderStopAll,
      );
      expect(isEnabled(tester, start), isTrue);
      expect(isEnabled(tester, stop), isFalse);

      await tester.tap(start);
      await tester.pump();
      verify(profileBlocs[sshUuid]!.add(const ProfileStartEvent())).called(1);

      runningCubit.prepare(sshUuid);
      await tester.pumpAndSettle();
      expect(isEnabled(tester, stop), isTrue);
    });

    testWidgets('grey out New folder and Move to, saying why', (
      WidgetTester tester,
    ) async {
      await pumpListView(
        tester,
        unsynced,
        child: const Row(
          children: <Widget>[
            ProfileFolderCreateButton(),
            ProfileFolderMoveButton(),
          ],
        ),
      );
      expect(tester.widget<ElevatedButton>(createButton).enabled, isFalse);
      expect(find.byTooltip(strings.folderSyncing), findsOneWidget);

      selectedCubit.selectOnly(<String>{sshUuid});
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(moveButton).enabled, isFalse);
      expect(find.byTooltip(strings.folderSyncing), findsOneWidget);
      expect(createButton, findsNothing);
    });

    testWidgets('are not changed by the actions behind the buttons', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);
      final BuildContext context = tester.element(find.byType(Scaffold));

      final Future<void> created = ProfileFolderActions.createFolder(context);
      final Future<void> renamed = ProfileFolderActions.renameFolder(
        context,
        serversFolder,
      );
      final Future<void> chosen = ProfileFolderActions.chooseStartAll(
        context,
        serversFolder,
      );
      final Future<bool> moved = ProfileFolderActions.moveToFolder(
        context,
        <String>[sshUuid],
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(await moved, isFalse);
      await Future.wait(<Future<void>>[created, renamed, chosen]);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('can be changed once they have synced', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, unsynced);
      expect(find.byKey(gripKey), findsNothing);

      folderBloc.emit(synced);
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byKey(gripKey), findsNWidgets(7));
      for (final ProfileFolder folder in twoFolders.folders) {
        expect(
          isEnabled(tester, headerButton(folder.uuid, strings.favoriteAdd)),
          isTrue,
          reason: '${folder.name} star',
        );
        expect(
          isEnabled(tester, headerButton(folder.uuid, strings.folderCollapse)),
          isTrue,
          reason: '${folder.name} collapse toggle',
        );
      }

      await openMenu(tester, header(serversFolder.uuid));
      expect(folderMenuEnabled(tester), <String, bool>{
        strings.folderAddConnection: true,
        strings.folderChooseStartAll: true,
        strings.folderRename: true,
        strings.folderMoveUp: false,
        strings.folderMoveDown: true,
        strings.folderDelete: true,
      });
      await closeMenu(tester);

      await openMenu(tester, header(desktopsFolder.uuid));
      expect(folderMenuEnabled(tester), <String, bool>{
        strings.folderAddConnection: true,
        strings.folderChooseStartAll: true,
        strings.folderRename: true,
        strings.folderMoveUp: true,
        strings.folderMoveDown: false,
        strings.folderDelete: true,
      });
      await closeMenu(tester);

      await openMenu(tester, row(sshUuid));
      expect(find.text(strings.folderMoveToFolder), findsOneWidget);
    });

    testWidgets('get working star and collapse toggle once synced', (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, synced);

      await tester.tap(headerButton(serversFolder.uuid, strings.favoriteAdd));
      await tester.pumpAndSettle();
      expect(folderRepo.puts.single.folders.first.favorite, isTrue);

      await tester.tap(
        headerButton(serversFolder.uuid, strings.folderCollapse),
      );
      await tester.pumpAndSettle();
      expect(row(sshUuid), findsNothing);
      expect(folderRepo.puts.last.folders.first.collapsed, isTrue);
    });

    testWidgets('turn New folder and Move to on once synced', (
      WidgetTester tester,
    ) async {
      await pumpListView(
        tester,
        unsynced,
        child: const Row(
          children: <Widget>[
            ProfileFolderCreateButton(),
            ProfileFolderMoveButton(),
          ],
        ),
      );
      selectedCubit.selectOnly(<String>{sshUuid});
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(moveButton).enabled, isFalse);

      folderBloc.emit(synced);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(moveButton).enabled, isTrue);
      expect(find.byTooltip(strings.folderSyncing), findsNothing);
      expect(createButton, findsNothing);

      selectedCubit.deselectAll();
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(createButton).enabled, isTrue);
      expect(moveButton, findsNothing);
    });
  });

  group('select all', () {
    const ProfileFolder collapsedServers = ProfileFolder(
      uuid: 'g-servers',
      name: 'Servers',
      profileIds: <String>[sshUuid, rdpUuid],
      collapsed: true,
    );

    Future<void> pumpSelectAll(
      WidgetTester tester,
      ProfileFolderState state, {
      String query = '',
    }) async {
      createRealBlocs();
      folderBloc.emit(state);
      filterCubit.setProfiles(allUuids);
      if (state is ProfileFoldersLoaded) filterCubit.setFolders(state.folders);
      if (query.isNotEmpty) filterCubit.search(query);
      await tester.pumpWidget(buildApp(tester, const ProfileSelectAllBox()));
      await tester.pump();
    }

    Future<void> tapSelectAll(WidgetTester tester) async {
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
    }

    bool? boxValue(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox)).value;

    testWidgets('selects every connection when none is hidden', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(tester, const ProfileFoldersLoaded(twoFolders));

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, allUuids.toSet());
      expect(boxValue(tester), isTrue);
    });

    testWidgets('selects only the connections a search shows', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(twoFolders),
        query: 'alpha',
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, <String>{sshUuid});
      expect(boxValue(tester), isTrue);
    });

    testWidgets('selects only matches in a list without folders', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(ProfileFolderData()),
        query: 'delta',
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, <String>{noneUuid});
    });

    testWidgets('leaves out connections inside a collapsed folder', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[collapsedServers, desktopsFolder],
          ),
        ),
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, <String>{
        vncUuid,
        noneUuid,
        extraUuid,
      });
      expect(boxValue(tester), isTrue);

      await tapSelectAll(tester);
      expect(selectedCubit.state.selected, isEmpty);
      expect(boxValue(tester), isFalse);
    });

    testWidgets('leaves out connections inside a collapsed No folder section', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[serversFolder, desktopsFolder],
            unfiledCollapsed: true,
          ),
        ),
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, <String>{sshUuid, rdpUuid, vncUuid});
    });

    testWidgets('ignores a collapsed No folder section when no folder exists', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(ProfileFolderData(unfiledCollapsed: true)),
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, allUuids.toSet());
    });

    testWidgets('counts collapsed folders as open while searching', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[collapsedServers, desktopsFolder],
          ),
        ),
        query: 'beta',
      );

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, <String>{rdpUuid});
    });

    testWidgets('selects every connection before the folders have loaded', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(tester, const ProfileFoldersInitial());

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, allUuids.toSet());
    });

    testWidgets('is unchecked, not all checked, when a search shows nothing', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(twoFolders),
        query: 'no connection is called this',
      );

      expect(boxValue(tester), isFalse);

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, isEmpty);
      expect(boxValue(tester), isFalse);
    });

    testWidgets('is unchecked when every connection is in a collapsed folder', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(
                uuid: 'g-everything',
                name: 'Everything',
                profileIds: allUuids,
                collapsed: true,
              ),
            ],
          ),
        ),
      );

      expect(boxValue(tester), isFalse);

      await tapSelectAll(tester);

      expect(selectedCubit.state.selected, isEmpty);
      expect(boxValue(tester), isFalse);
    });

    testWidgets('is no longer all checked once a collapsed folder opens', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(
        tester,
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[collapsedServers, desktopsFolder],
          ),
        ),
      );
      await tapSelectAll(tester);
      expect(boxValue(tester), isTrue);

      folderBloc.emit(const ProfileFoldersLoaded(twoFolders));
      await tester.pumpAndSettle();

      expect(boxValue(tester), isNull);
      await tapSelectAll(tester);
      expect(selectedCubit.state.selected, allUuids.toSet());
    });

    testWidgets('is all checked once a search shows only selected ones', (
      WidgetTester tester,
    ) async {
      await pumpSelectAll(tester, const ProfileFoldersLoaded(twoFolders));
      selectedCubit.selectOnly(<String>{sshUuid});
      await tester.pumpAndSettle();
      expect(boxValue(tester), isNull);

      filterCubit.search('alpha');
      await tester.pumpAndSettle();

      expect(boxValue(tester), isTrue);
      await tapSelectAll(tester);
      expect(selectedCubit.state.selected, isEmpty);
    });
  });

  group('folder name dialog', () {
    String? result;
    bool closed = false;

    Future<void> pumpNameDialog(
      WidgetTester tester, {
      String? initialName,
      Iterable<String> takenNames = const <String>[],
    }) async {
      result = null;
      closed = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (BuildContext _) => ProfileFolderNameDialog(
                      title: strings.folderNew,
                      initialName: initialName,
                      takenNames: takenNames,
                    ),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> saveName(WidgetTester tester, String name) async {
      await tester.enterText(find.byKey(nameFieldKey), name);
      await tester.tap(find.text(strings.save));
      await tester.pumpAndSettle();
    }

    Future<void> submitName(WidgetTester tester, String name) async {
      await tester.enterText(find.byKey(nameFieldKey), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    String typedName(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(nameFieldKey),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;

    testWidgets('refuses a name that is already in use', (
      WidgetTester tester,
    ) async {
      await pumpNameDialog(tester, takenNames: <String>['Servers', 'Desktops']);

      await saveName(tester, 'Servers');

      expect(find.text(strings.folderNameTaken), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('refuses a name in use whatever its letter case', (
      WidgetTester tester,
    ) async {
      await pumpNameDialog(tester, takenNames: <String>['Servers']);

      await saveName(tester, 'sERVERS');
      expect(find.text(strings.folderNameTaken), findsOneWidget);

      await saveName(tester, '  SERVERS  ');
      expect(find.text(strings.folderNameTaken), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('accepts a free name and returns it trimmed', (
      WidgetTester tester,
    ) async {
      await pumpNameDialog(tester, takenNames: <String>['Servers']);

      await saveName(tester, '  Servers 2  ');

      expect(closed, isTrue);
      expect(result, 'Servers 2');
    });

    testWidgets('lets the same name through when it is not listed as taken', (
      WidgetTester tester,
    ) async {
      await pumpNameDialog(tester, initialName: 'Servers');

      await saveName(tester, 'SERVERS');

      expect(result, 'SERVERS');
    });

    testWidgets('still refuses an empty name', (WidgetTester tester) async {
      await pumpNameDialog(tester, takenNames: <String>['Servers']);

      await saveName(tester, '   ');

      expect(find.text(strings.folderNameRequired), findsOneWidget);
      expect(closed, isFalse);
    });

    group('Enter', () {
      testWidgets('saves the name like the Save button, trimmed', (
        WidgetTester tester,
      ) async {
        await pumpNameDialog(tester, takenNames: <String>['Servers']);

        await submitName(tester, '  Servers 2  ');

        expect(closed, isTrue);
        expect(result, 'Servers 2');
      });

      testWidgets('refuses a name that is already in use', (
        WidgetTester tester,
      ) async {
        await pumpNameDialog(tester, takenNames: <String>['Servers']);

        await submitName(tester, 'servers');

        expect(find.text(strings.folderNameTaken), findsOneWidget);
        expect(closed, isFalse);
      });

      testWidgets('refuses an empty name', (WidgetTester tester) async {
        await pumpNameDialog(tester);

        await submitName(tester, '   ');

        expect(find.text(strings.folderNameRequired), findsOneWidget);
        expect(closed, isFalse);
      });
    });

    group('length', () {
      testWidgets('stops at 64 characters', (WidgetTester tester) async {
        await pumpNameDialog(tester);

        await tester.enterText(find.byKey(nameFieldKey), 'a' * 70);
        await tester.pump();
        expect(typedName(tester), 'a' * 64);

        await tester.tap(find.text(strings.save));
        await tester.pumpAndSettle();
        expect(result, 'a' * 64);
      });

      testWidgets('lets a name of exactly 64 characters through', (
        WidgetTester tester,
      ) async {
        await pumpNameDialog(tester);

        await saveName(tester, 'b' * 64);

        expect(result, 'b' * 64);
      });

      testWidgets('keeps the first 64 when more are pasted over a name', (
        WidgetTester tester,
      ) async {
        await pumpNameDialog(tester, initialName: 'Servers');

        await tester.enterText(find.byKey(nameFieldKey), 'Servers ${'x' * 80}');
        await tester.pump();

        expect(typedName(tester), 'Servers ${'x' * 56}');
      });

      testWidgets('counts a letter and its combining accent as one character', (
        WidgetTester tester,
      ) async {
        await pumpNameDialog(tester);
        const String accented = 'é';

        await tester.enterText(find.byKey(nameFieldKey), accented * 70);
        await tester.pump();

        expect(typedName(tester), accented * 64);
      });
    });

    group('from the folder menus', () {
      Future<void> startRename(WidgetTester tester) async {
        await pumpListView(tester, const ProfileFoldersLoaded(twoFolders));
        await openMenu(tester, header(serversFolder.uuid));
        await tester.tap(find.text(strings.folderRename));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byKey(nameFieldKey), findsOneWidget);
      }

      testWidgets('renaming allows the folder own name in another case', (
        WidgetTester tester,
      ) async {
        await startRename(tester);

        await saveName(tester, 'SERVERS');

        expect(find.byKey(nameFieldKey), findsNothing);
        expect(find.text('SERVERS'), findsOneWidget);
        expect(folderRepo.puts.single.folders.first.name, 'SERVERS');
      });

      testWidgets('renaming refuses a name another folder has in any case', (
        WidgetTester tester,
      ) async {
        await startRename(tester);

        await saveName(tester, 'DESKTOPS');

        expect(find.text(strings.folderNameTaken), findsOneWidget);
        expect(find.byKey(nameFieldKey), findsOneWidget);
        expect(folderRepo.puts, isEmpty);
      });

      testWidgets('renaming to the unchanged name sends no event', (
        WidgetTester tester,
      ) async {
        await startRename(tester);

        await saveName(tester, 'Servers');

        expect(find.byKey(nameFieldKey), findsNothing);
        expect(folderBloc.events, isEmpty);
        expect(folderRepo.puts, isEmpty);
      });

      testWidgets('renaming to the unchanged name with spaces around it '
          'sends no event', (WidgetTester tester) async {
        await startRename(tester);

        await saveName(tester, '  Servers  ');

        expect(find.byKey(nameFieldKey), findsNothing);
        expect(folderBloc.events, isEmpty);
      });

      testWidgets('renaming to another case does send the event', (
        WidgetTester tester,
      ) async {
        await startRename(tester);

        await saveName(tester, 'SERVERS');

        expect(
          folderBloc.events.single,
          isA<ProfileFolderRenameEvent>()
              .having((ProfileFolderRenameEvent e) => e.name, 'name', 'SERVERS')
              .having(
                (ProfileFolderRenameEvent e) => e.folderId,
                'folderId',
                serversFolder.uuid,
              ),
        );
      });

      testWidgets('pressing Enter renames the folder', (
        WidgetTester tester,
      ) async {
        await startRename(tester);

        await submitName(tester, 'Machines');

        expect(find.byKey(nameFieldKey), findsNothing);
        expect(find.text('Machines'), findsOneWidget);
        expect(folderRepo.puts.single.folders.first.name, 'Machines');
      });

      testWidgets('cancelling the rename sends no event', (
        WidgetTester tester,
      ) async {
        await startRename(tester);
        await tester.enterText(find.byKey(nameFieldKey), 'Machines');

        await tester.tap(find.text(strings.cancel));
        await tester.pumpAndSettle();

        expect(find.byKey(nameFieldKey), findsNothing);
        expect(folderBloc.events, isEmpty);
      });

      testWidgets('New folder refuses every existing name in any case', (
        WidgetTester tester,
      ) async {
        await pumpListView(
          tester,
          const ProfileFoldersLoaded(twoFolders),
          child: const ProfileFolderCreateButton(),
        );
        await tester.tap(find.text(strings.folderNew));
        await tester.pumpAndSettle();

        await saveName(tester, 'desktops');
        expect(find.text(strings.folderNameTaken), findsOneWidget);
        await saveName(tester, 'SERVERS');
        expect(find.text(strings.folderNameTaken), findsOneWidget);
        expect(folderRepo.puts, isEmpty);

        await saveName(tester, 'Laptops');
        expect(find.byKey(nameFieldKey), findsNothing);
        expect(
          folderRepo.puts.single.folders.map((ProfileFolder f) => f.name),
          <String>['Servers', 'Desktops', 'Laptops'],
        );
      });
    });
  });

  group('folder picker', () {
    const ProfileFolderData placed = ProfileFolderData(
      folders: <ProfileFolder>[serversFolder, desktopsFolder],
      unfiled: <String>[noneUuid],
    );

    Finder option(String id) =>
        find.byKey(Key('ProfileFolderPickerDialog-$id'));
    bool isMarked(WidgetTester tester, String id) {
      final Text label = tester.widget<Text>(
        find.descendant(of: option(id), matching: find.byType(Text)),
      );
      return label.style?.fontWeight == FontWeight.w600;
    }

    Map<String, bool> marks(WidgetTester tester) => <String, bool>{
      for (final String id in <String>[
        serversFolder.uuid,
        desktopsFolder.uuid,
        'none',
      ])
        id: isMarked(tester, id),
    };

    Future<void> openPickerFor(
      WidgetTester tester,
      Set<String> selection,
    ) async {
      await pumpListView(
        tester,
        const ProfileFoldersLoaded(placed),
        child: const ProfileFolderMoveButton(),
      );
      selectedCubit.selectOnly(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.folderMoveTo));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(strings.folderMoveToFolder), findsOneWidget);
    }

    final Map<String, (Set<String>, Map<String, bool>)>
    cases = <String, (Set<String>, Map<String, bool>)>{
      'several connections in one folder mark that folder': (
        <String>{sshUuid, rdpUuid},
        <String, bool>{'g-servers': true, 'g-desktops': false, 'none': false},
      ),
      'one connection in a folder marks that folder': (
        <String>{vncUuid},
        <String, bool>{'g-servers': false, 'g-desktops': true, 'none': false},
      ),
      'several unfiled connections mark No folder': (
        <String>{noneUuid, extraUuid},
        <String, bool>{'g-servers': false, 'g-desktops': false, 'none': true},
      ),
      'connections in two folders mark nothing': (
        <String>{sshUuid, vncUuid},
        <String, bool>{'g-servers': false, 'g-desktops': false, 'none': false},
      ),
      'a folder and an unfiled connection mark nothing': (
        <String>{sshUuid, noneUuid},
        <String, bool>{'g-servers': false, 'g-desktops': false, 'none': false},
      ),
    };
    cases.forEach((String name, (Set<String>, Map<String, bool>) expected) {
      testWidgets('with $name', (WidgetTester tester) async {
        await openPickerFor(tester, expected.$1);

        expect(marks(tester), expected.$2);
      });
    });

    testWidgets('picking a folder moves every selected connection there and '
        'clears the selection', (WidgetTester tester) async {
      await openPickerFor(tester, <String>{sshUuid, rdpUuid});

      await tester.tap(option(desktopsFolder.uuid));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      final ProfileFolderData saved = folderRepo.puts.single;
      expect(saved.folders.first.profileIds, isEmpty);
      expect(saved.folders.last.profileIds, <String>[
        vncUuid,
        sshUuid,
        rdpUuid,
      ]);
      expect(selectedCubit.state.selected, isEmpty);
    });

    testWidgets('picking No folder unfiles every selected connection', (
      WidgetTester tester,
    ) async {
      await openPickerFor(tester, <String>{sshUuid, rdpUuid});

      await tester.tap(option('none'));
      await tester.pumpAndSettle();

      final ProfileFolderData saved = folderRepo.puts.single;
      expect(saved.folders.first.profileIds, isEmpty);
      expect(saved.unfiled, containsAll(<String>[sshUuid, rdpUuid]));
      expect(selectedCubit.state.selected, isEmpty);
    });

    testWidgets("the connection menu's Move to folder marks its folder", (
      WidgetTester tester,
    ) async {
      await pumpListView(tester, const ProfileFoldersLoaded(placed));

      await openMenu(tester, row(vncUuid));
      await tester.tap(find.text(strings.folderMoveToFolder));
      await tester.pumpAndSettle();

      expect(marks(tester), <String, bool>{
        'g-servers': false,
        'g-desktops': true,
        'none': false,
      });
    });

    group('dialog on its own', () {
      Future<void> pumpDialog(
        WidgetTester tester, {
        String? currentFolderId,
        bool hasCurrent = true,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProfileFolderPickerDialog(
                folders: twoFolders.folders,
                currentFolderId: currentFolderId,
                hasCurrent: hasCurrent,
              ),
            ),
          ),
        );
      }

      testWidgets('marks nothing when the places differ', (
        WidgetTester tester,
      ) async {
        await pumpDialog(
          tester,
          currentFolderId: serversFolder.uuid,
          hasCurrent: false,
        );

        expect(marks(tester), <String, bool>{
          'g-servers': false,
          'g-desktops': false,
          'none': false,
        });
      });

      testWidgets('marks No folder when the connections are all unfiled', (
        WidgetTester tester,
      ) async {
        await pumpDialog(tester);

        expect(marks(tester), <String, bool>{
          'g-servers': false,
          'g-desktops': false,
          'none': true,
        });
      });

      testWidgets('marks the folder it is given', (WidgetTester tester) async {
        await pumpDialog(tester, currentFolderId: serversFolder.uuid);

        expect(marks(tester), <String, bool>{
          'g-servers': true,
          'g-desktops': false,
          'none': false,
        });
      });
    });
  });

  group('Start all while searching', () {
    const ProfileFolder machines = ProfileFolder(
      uuid: 'g-machines',
      name: 'Machines',
      profileIds: <String>[sshUuid, rdpUuid, vncUuid, 'uuid-not-loaded'],
    );
    const ProfileFolder others = ProfileFolder(
      uuid: 'g-others',
      name: 'Others',
      profileIds: <String>[noneUuid],
    );

    Future<void> pumpSearch(
      WidgetTester tester,
      String query, {
      ProfileFolder folder = machines,
    }) async {
      final ProfileListFilterState filter = ProfileListFilterState(
        query: query,
        profiles: <String, Profile>{
          for (final String uuid in allUuids) uuid: buildProfile(uuid),
        },
        folders: <ProfileFolder>[folder, others],
      );
      await pumpListView(
        tester,
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[folder, others]),
        ),
        child: ProfileFolderListView(
          profiles: allUuids,
          searching: filter.searching,
          arrange: filter.isDefault
              ? null
              : (List<String> uuids) => filter.apply(uuids, const <String>{}),
          folderMatches: filter.folderMatches,
          reorderable: filter.manualOrder,
          movable: !filter.searching,
        ),
      );
    }

    Finder tooltipIn(String folderId, String tooltip) => find.descendant(
      of: header(folderId),
      matching: find.byTooltip(tooltip),
    );

    testWidgets("says how many of the folder's connections it starts", (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester, 'alpha');

      expect(strings.folderStartSome(1, 3), 'Start 1 of 3');
      expect(
        tooltipIn(machines.uuid, strings.folderStartSome(1, 3)),
        findsOneWidget,
      );
      expect(tooltipIn(machines.uuid, strings.folderStartAll), findsNothing);
      expect(row(sshUuid), findsOneWidget);
      expect(row(rdpUuid), findsNothing);
    });

    testWidgets('starts only the connections the search shows', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester, 'alpha');

      await tester.tap(tooltipIn(machines.uuid, strings.folderStartSome(1, 3)));
      await tester.pump();

      verify(profileBlocs[sshUuid]!.add(const ProfileStartEvent())).called(1);
      verifyNever(profileBlocs[rdpUuid]!.add(const ProfileStartEvent()));
      verifyNever(profileBlocs[vncUuid]!.add(const ProfileStartEvent()));
      verifyNever(profileBlocs[noneUuid]!.add(const ProfileStartEvent()));
      verifyNever(profileBlocs[extraUuid]!.add(const ProfileStartEvent()));
    });

    testWidgets('keeps Start all when the search shows every connection', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester, 'a');

      expect(tooltipIn(machines.uuid, strings.folderStartAll), findsOneWidget);
      expect(find.byType(ProfileListRow), findsNWidgets(5));
    });

    testWidgets('keeps Start all when the folder name matches the search', (
      WidgetTester tester,
    ) async {
      await pumpSearch(tester, 'machines');

      expect(tooltipIn(machines.uuid, strings.folderStartAll), findsOneWidget);
      expect(row(sshUuid), findsOneWidget);
      expect(row(rdpUuid), findsOneWidget);
      expect(row(vncUuid), findsOneWidget);
    });

    testWidgets('takes the connections Start all skips off the shown count', (
      WidgetTester tester,
    ) async {
      await pumpSearch(
        tester,
        'a',
        folder: machines.copyWith(skippedByStartAll: <String>[rdpUuid]),
      );

      expect(
        tooltipIn(machines.uuid, strings.folderStartSome(2, 3)),
        findsOneWidget,
      );
    });

    testWidgets('is the plain Start all without a search', (
      WidgetTester tester,
    ) async {
      await pumpListView(
        tester,
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[machines, others]),
        ),
      );

      expect(tooltipIn(machines.uuid, strings.folderStartAll), findsOneWidget);
    });
  });

  group('Choose connections to start', () {
    const String missingUuid = 'uuid-not-loaded';
    const ProfileFolder machines = ProfileFolder(
      uuid: 'g-machines',
      name: 'Machines',
      profileIds: <String>[sshUuid, rdpUuid, vncUuid, missingUuid],
    );

    ProfileFoldersLoaded loadedWith(ProfileFolder folder) =>
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[folder],
            unfiled: const <String>[noneUuid, extraUuid],
          ),
        );

    Finder tile(String uuid) =>
        find.byKey(Key('ProfileFolderStartAllDialog-$uuid'));
    bool isChecked(WidgetTester tester, String uuid) =>
        tester.widget<CheckboxListTile>(tile(uuid)).value!;
    Future<void> toggleTile(WidgetTester tester, String uuid) async {
      await tester.tap(tile(uuid));
      await tester.pump();
    }

    Future<void> pressSave(WidgetTester tester) async {
      await tester.tap(find.text(strings.save));
      await tester.pumpAndSettle();
    }

    Future<void> openChooser(WidgetTester tester, ProfileFolder folder) async {
      await openMenu(tester, header(folder.uuid));
      await tester.tap(find.text(strings.folderChooseStartAll));
      await tester.pumpAndSettle();
    }

    Future<void> pumpAndChoose(
      WidgetTester tester,
      ProfileFolder folder,
    ) async {
      await pumpListView(tester, loadedWith(folder));
      await openChooser(tester, folder);
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    ProfileStartQueueCubit queueOf(WidgetTester tester) =>
        tester.element(find.byType(Scaffold)).read<ProfileStartQueueCubit>();

    List<String> skippedInSaved() =>
        folderRepo.puts.single.folders.single.skippedByStartAll;

    testWidgets('opens with the connections Start all skips unchecked', (
      WidgetTester tester,
    ) async {
      await pumpAndChoose(
        tester,
        machines.copyWith(skippedByStartAll: <String>[rdpUuid, missingUuid]),
      );

      expect(isChecked(tester, sshUuid), isTrue);
      expect(isChecked(tester, rdpUuid), isFalse);
      expect(isChecked(tester, vncUuid), isTrue);
      expect(tile(missingUuid), findsNothing);
    });

    testWidgets('saves the unchecked ones as skipped and the checked ones as '
        'started', (WidgetTester tester) async {
      await pumpAndChoose(
        tester,
        machines.copyWith(skippedByStartAll: <String>[rdpUuid]),
      );

      await toggleTile(tester, rdpUuid);
      await toggleTile(tester, sshUuid);
      await pressSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(skippedInSaved(), <String>[sshUuid]);
    });

    testWidgets('keeps the skip flag of members the dialog does not list', (
      WidgetTester tester,
    ) async {
      await pumpAndChoose(
        tester,
        machines.copyWith(skippedByStartAll: <String>[rdpUuid, missingUuid]),
      );

      await toggleTile(tester, rdpUuid);
      await toggleTile(tester, vncUuid);
      await pressSave(tester);

      expect(skippedInSaved(), <String>[missingUuid, vncUuid]);
    });

    testWidgets('does not skip a member it does not list when none had been', (
      WidgetTester tester,
    ) async {
      await pumpAndChoose(tester, machines);

      await toggleTile(tester, vncUuid);
      await pressSave(tester);

      expect(skippedInSaved(), <String>[vncUuid]);
    });

    testWidgets(
      'keeps what a sync set for unlisted members while it was open',
      (WidgetTester tester) async {
        await pumpAndChoose(tester, machines);

        folderBloc.emit(
          loadedWith(
            machines.copyWith(skippedByStartAll: <String>[missingUuid]),
          ),
        );
        await tester.pump();
        await toggleTile(tester, vncUuid);
        await pressSave(tester);

        expect(skippedInSaved(), <String>[missingUuid, vncUuid]);
      },
    );

    testWidgets('saves nothing when the folder was deleted while it was open', (
      WidgetTester tester,
    ) async {
      await pumpAndChoose(tester, machines);

      folderBloc.emit(const ProfileFoldersLoaded(ProfileFolderData()));
      await tester.pump();
      await toggleTile(tester, vncUuid);
      await pressSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(folderBloc.events, isEmpty);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('Cancel saves nothing', (WidgetTester tester) async {
      await pumpAndChoose(tester, machines);

      await toggleTile(tester, vncUuid);
      await tester.tap(find.text(strings.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(folderBloc.events, isEmpty);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('cannot be saved with every connection unchecked', (
      WidgetTester tester,
    ) async {
      await pumpAndChoose(tester, machines);
      final Finder save = find.widgetWithText(TextButton, strings.save);

      for (final String uuid in <String>[sshUuid, rdpUuid, vncUuid]) {
        await toggleTile(tester, uuid);
      }
      expect(tester.widget<TextButton>(save).onPressed, isNull);

      await toggleTile(tester, rdpUuid);
      expect(tester.widget<TextButton>(save).onPressed, isNotNull);
    });

    testWidgets('does not open for a folder with no connection loaded', (
      WidgetTester tester,
    ) async {
      const ProfileFolder ghosts = ProfileFolder(
        uuid: 'g-ghosts',
        name: 'Ghosts',
        profileIds: <String>[missingUuid],
      );
      await pumpListView(tester, loadedWith(ghosts));

      await openChooser(tester, ghosts);

      expect(find.byType(AlertDialog), findsNothing);
      expect(folderRepo.puts, isEmpty);
    });

    group('connections still waiting from an earlier Start all', () {
      Future<ProfileStartQueueCubit> pumpWithStartAllRunning(
        WidgetTester tester,
        ProfileFolder folder,
      ) async {
        final StreamController<ProfileState> stuck =
            StreamController<ProfileState>.broadcast();
        addTearDown(stuck.close);
        when(profileBlocs[sshUuid]!.stream).thenAnswer((_) => stuck.stream);

        await pumpListView(tester, loadedWith(folder));
        final ProfileStartQueueCubit queue = queueOf(tester);
        await tester.tap(headerButton(folder.uuid, strings.folderStartAll));
        await tester.pump();
        return queue;
      }

      testWidgets('leave the queue when unchecked', (
        WidgetTester tester,
      ) async {
        final ProfileStartQueueCubit queue = await pumpWithStartAllRunning(
          tester,
          machines,
        );
        expect(queue.state.waiting, <String>[rdpUuid, vncUuid]);

        await openChooser(tester, machines);
        await toggleTile(tester, rdpUuid);
        await pressSave(tester);

        expect(queue.state.waiting, <String>[vncUuid]);
        expect(skippedInSaved(), <String>[rdpUuid]);

        queue.clear();
        await tester.pump();
      });

      testWidgets('stay in the queue when still checked', (
        WidgetTester tester,
      ) async {
        final ProfileStartQueueCubit queue = await pumpWithStartAllRunning(
          tester,
          machines,
        );

        await openChooser(tester, machines);
        await toggleTile(tester, sshUuid);
        await pressSave(tester);

        expect(queue.state.waiting, <String>[rdpUuid, vncUuid]);

        queue.clear();
        await tester.pump();
      });

      testWidgets('of another folder are left in the queue', (
        WidgetTester tester,
      ) async {
        final ProfileStartQueueCubit queue = await pumpWithStartAllRunning(
          tester,
          machines,
        );
        queue.add(<String>[noneUuid, extraUuid]);
        expect(queue.state.waiting, <String>[
          rdpUuid,
          vncUuid,
          noneUuid,
          extraUuid,
        ]);

        await openChooser(tester, machines);
        await toggleTile(tester, rdpUuid);
        await toggleTile(tester, vncUuid);
        await pressSave(tester);

        expect(queue.state.waiting, <String>[noneUuid, extraUuid]);

        queue.clear();
        await tester.pump();
      });
    });

    group('connections never shown', () {
      final ProfileFolder collapsedServers = serversFolder.copyWith(
        collapsed: true,
      );

      setUp(() {
        final ProfileState notLoaded = const ProfileInitial(sshUuid);
        when(profileBlocs[sshUuid]!.state).thenReturn(notLoaded);
        when(
          profileBlocs[sshUuid]!.stream,
        ).thenAnswer((_) => Stream<ProfileState>.value(notLoaded));
      });

      testWidgets('are loaded before the dialog opens', (
        WidgetTester tester,
      ) async {
        await pumpListView(tester, loadedWith(collapsedServers));
        expect(row(sshUuid), findsNothing);
        verifyNever(profileBlocs[sshUuid]!.add(const ProfileLoadEvent()));

        await openChooser(tester, collapsedServers);

        verify(profileBlocs[sshUuid]!.add(const ProfileLoadEvent())).called(1);
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('are not asked again when already loaded or not members', (
        WidgetTester tester,
      ) async {
        await pumpListView(tester, loadedWith(collapsedServers));

        await openChooser(tester, collapsedServers);

        verifyNever(profileBlocs[rdpUuid]!.add(const ProfileLoadEvent()));
        verifyNever(profileBlocs[vncUuid]!.add(const ProfileLoadEvent()));
        verifyNever(profileBlocs[noneUuid]!.add(const ProfileLoadEvent()));
      });

      testWidgets('are listed as loading until their name is known', (
        WidgetTester tester,
      ) async {
        await pumpListView(tester, loadedWith(collapsedServers));

        await openChooser(tester, collapsedServers);

        expect(
          find.descendant(
            of: tile(sshUuid),
            matching: find.text(strings.profileStatusLoading),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile(rdpUuid), matching: find.text('Beta')),
          findsOneWidget,
        );
      });
    });
  });
}
