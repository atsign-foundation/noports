import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
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
  // What a refresh reads; null reads as a failed read.
  ProfileFolderData? stored;
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  @override
  Future<ProfileFolderData?> getProfileFolders() async => stored;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    puts.add(data);
    stored = data;
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
  const String noneUuid = 'uuid-none';
  const List<String> allUuids = <String>[sshUuid, rdpUuid, noneUuid];

  Profile buildProfile(String uuid, String? protocol) => Profile(
    uuid,
    displayName: 'Profile $uuid',
    sshnpdAtsign: '@device'.toAtsign(),
    deviceName: 'device',
    remotePort: 22,
    localPort: 2222,
    connectUriProtocol: protocol,
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
    profileIds: <String>[sshUuid, 'uuid-not-loaded'],
  );
  const ProfileFolder desktopsFolder = ProfileFolder(
    uuid: 'g-desktops',
    name: 'Desktops',
    profileIds: <String>[rdpUuid],
  );

  late MockProfileCacheCubit mockCache;
  late Map<String, MockProfileBloc> profileBlocs;
  late MockSettingsBloc mockSettingsBloc;
  late MockProfilesSelectedCubit mockSelectedCubit;
  late MockProfileListBloc mockListBloc;
  late MockFavoriteBloc mockFavoriteBloc;
  late ProfilesRunningCubit runningCubit;
  late FakeProfileFolderRepository folderRepo;
  late RecordingProfileFolderBloc folderBloc;

  setUp(() {
    provideDummy<ProfileState>(const ProfileInitial('dummy'));
    provideDummy<SettingsState>(const SettingsInitial());
    provideDummy<ProfilesSelectedState>(const ProfilesSelectedState({}));
    provideDummy<FavoritesState>(const FavoritesInitial());

    mockCache = MockProfileCacheCubit();
    profileBlocs = <String, MockProfileBloc>{};
    final Map<String, String?> protocols = <String, String?>{
      sshUuid: 'ssh',
      rdpUuid: 'rdp',
      noneUuid: '',
    };
    protocols.forEach((String uuid, String? protocol) {
      final MockProfileBloc bloc = MockProfileBloc();
      final ProfileState state = ProfileLoaded(
        uuid,
        profile: buildProfile(uuid, protocol),
      );
      when(bloc.uuid).thenReturn(uuid);
      when(bloc.state).thenReturn(state);
      when(bloc.stream).thenAnswer((_) => Stream<ProfileState>.value(state));
      when(mockCache.getProfileBloc(uuid)).thenReturn(bloc);
      profileBlocs[uuid] = bloc;
    });

    mockSettingsBloc = MockSettingsBloc();
    when(
      mockSettingsBloc.state,
    ).thenReturn(SettingsLoaded(settings: testSettings));
    when(mockSettingsBloc.stream).thenAnswer(
      (_) =>
          Stream<SettingsState>.value(SettingsLoaded(settings: testSettings)),
    );

    provideDummy<ProfileListState>(const ProfileListInitial());
    mockListBloc = MockProfileListBloc();
    when(
      mockListBloc.state,
    ).thenReturn(const ProfileListLoaded(profiles: allUuids));
    when(mockListBloc.stream).thenAnswer(
      (_) => Stream<ProfileListState>.value(
        const ProfileListLoaded(profiles: allUuids),
      ),
    );

    mockSelectedCubit = MockProfilesSelectedCubit();
    when(mockSelectedCubit.state).thenReturn(const ProfilesSelectedState({}));
    when(mockSelectedCubit.stream).thenAnswer(
      (_) =>
          Stream<ProfilesSelectedState>.value(const ProfilesSelectedState({})),
    );

    mockFavoriteBloc = MockFavoriteBloc();
    when(mockFavoriteBloc.state).thenReturn(const FavoritesLoaded([]));
    when(mockFavoriteBloc.stream).thenAnswer(
      (_) => Stream<FavoritesState>.value(const FavoritesLoaded([])),
    );
  });

  // The real blocs must be created inside the test body so that their stream
  // subscriptions live in the FakeAsync zone driven by [WidgetTester.pump].
  void createRealBlocs() {
    runningCubit = ProfilesRunningCubit();
    folderRepo = FakeProfileFolderRepository();
    folderBloc = RecordingProfileFolderBloc(folderRepo);
    addTearDown(() async {
      await runningCubit.close();
      await folderBloc.close();
    });
  }

  Widget buildSubject(
    WidgetTester tester, {
    List<String> profiles = allUuids,
    List<String> Function(List<String> uuids)? arrange,
    int Function(ProfileFolder a, ProfileFolder b)? compareFolders,
    String? sortedDropMessage,
    bool searching = false,
    bool reorderable = true,
    bool movable = false,
  }) {
    tester.view.physicalSize = const Size(1053, 691);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A snack bar is shown through the app's navigator key, which also logs.
    final bool snackBars = sortedDropMessage != null;
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        if (snackBars) ...<BlocProvider<dynamic>>[
          BlocProvider<EnableLoggingCubit>(
            create: (_) => EnableLoggingCubit()..disable(),
          ),
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
        ],
        BlocProvider<ProfileCacheCubit>.value(value: mockCache),
        BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
        BlocProvider<ProfilesSelectedCubit>.value(value: mockSelectedCubit),
        BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
        BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
        BlocProvider<ProfileStartQueueCubit>(
          create: (_) => ProfileStartQueueCubit(mockCache),
        ),
        BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
        BlocProvider<ProfileListBloc>.value(value: mockListBloc),
      ],
      child: MaterialApp(
        navigatorKey: snackBars ? App.navState : null,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileFolderListView(
            profiles: profiles,
            arrange: arrange,
            compareFolders: compareFolders,
            sortedDropMessage: sortedDropMessage,
            searching: searching,
            reorderable: reorderable,
            movable: movable,
          ),
        ),
      ),
    );
  }

  Finder header(String id) =>
      find.byKey(ValueKey<String>('ProfileFolderSectionHeader-$id'));
  Finder row(String uuid) =>
      find.byKey(ValueKey<String>('ProfileListRow-$uuid'));

  testWidgets('renders a flat list while folders have not loaded', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(find.byType(ProfileFolderSectionHeader), findsNothing);
  });

  testWidgets('renders a flat list when loaded without any folders', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(const ProfileFoldersLoaded(ProfileFolderData()));
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(find.byType(ProfileFolderSectionHeader), findsNothing);
  });

  testWidgets('renders folders in order followed by the unfiled section', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(
      const ProfileFoldersLoaded(
        ProfileFolderData(
          folders: <ProfileFolder>[serversFolder, desktopsFolder],
        ),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(header(serversFolder.uuid), findsOneWidget);
    expect(header(desktopsFolder.uuid), findsOneWidget);
    expect(header(ProfileFolderListView.unfiledSectionId), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('Desktops'), findsOneWidget);
    expect(find.text(strings.folderNone), findsOneWidget);
    expect(find.byType(ProfileListRow), findsNWidgets(3));

    // Profile ids that are not loaded do not count towards the folder.
    final Finder serversCount = find.descendant(
      of: header(serversFolder.uuid),
      matching: find.text('1'),
    );
    expect(serversCount, findsOneWidget);

    // Vertical order: Servers, ssh row, Desktops, rdp row, Unfiled, none row.
    final double serversY = tester.getTopLeft(header(serversFolder.uuid)).dy;
    final double sshY = tester.getTopLeft(row(sshUuid)).dy;
    final double desktopsY = tester.getTopLeft(header(desktopsFolder.uuid)).dy;
    final double rdpY = tester.getTopLeft(row(rdpUuid)).dy;
    final double unfiledY = tester
        .getTopLeft(header(ProfileFolderListView.unfiledSectionId))
        .dy;
    final double noneY = tester.getTopLeft(row(noneUuid)).dy;
    expect(serversY, lessThan(sshY));
    expect(sshY, lessThan(desktopsY));
    expect(desktopsY, lessThan(rdpY));
    expect(rdpY, lessThan(unfiledY));
    expect(unfiledY, lessThan(noneY));
  });

  testWidgets('collapsing a folder hides its rows only', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(
      const ProfileFoldersLoaded(
        ProfileFolderData(
          folders: <ProfileFolder>[serversFolder, desktopsFolder],
        ),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversFolder.uuid),
        matching: find.byTooltip(strings.folderCollapse),
      ),
    );
    await tester.pump();

    expect(row(sshUuid), findsNothing);
    expect(row(rdpUuid), findsOneWidget);
    expect(row(noneUuid), findsOneWidget);
    expect(
      find.descendant(
        of: header(serversFolder.uuid),
        matching: find.byTooltip(strings.folderExpand),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'start all sends ProfileStartEvent to each profile in the folder',
    (WidgetTester tester) async {
      createRealBlocs();
      folderBloc.emit(
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[serversFolder, desktopsFolder],
          ),
        ),
      );
      await tester.pumpWidget(buildSubject(tester));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: header(serversFolder.uuid),
          matching: find.byTooltip(strings.folderStartAll),
        ),
      );
      await tester.pump();

      verify(profileBlocs[sshUuid]!.add(const ProfileStartEvent())).called(1);
      verifyNever(profileBlocs[rdpUuid]!.add(const ProfileStartEvent()));
      verifyNever(profileBlocs[noneUuid]!.add(const ProfileStartEvent()));
    },
  );

  testWidgets('stop all is disabled until something in the folder is running', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(
      const ProfileFoldersLoaded(
        ProfileFolderData(folders: <ProfileFolder>[serversFolder]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    Finder stopButton() => find.descendant(
      of: header(serversFolder.uuid),
      matching: find.ancestor(
        of: find.byTooltip(strings.folderStopAll),
        matching: find.byType(IconButton),
      ),
    );
    IconButton stop() => tester.widget<IconButton>(stopButton().first);
    expect(stop().onPressed, isNull);

    runningCubit.prepare(sshUuid);
    await tester.pumpAndSettle();
    expect(stop().onPressed, isNotNull);
  });

  testWidgets('deleting a folder through its menu keeps the connections', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(
      const ProfileFoldersLoaded(
        ProfileFolderData(
          folders: <ProfileFolder>[serversFolder, desktopsFolder],
        ),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversFolder.uuid),
        matching: find.byType(PopupMenuButton<PopupMenuEntry>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.folderDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(header(serversFolder.uuid), findsNothing);
    expect(header(desktopsFolder.uuid), findsOneWidget);
    expect(header(ProfileFolderListView.unfiledSectionId), findsOneWidget);
    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(folderRepo.puts.single.folders, <ProfileFolder>[desktopsFolder]);
    // The folder's members go after what unfiled already showed.
    expect(folderRepo.puts.single.unfiled, <String>[
      noneUuid,
      sshUuid,
      'uuid-not-loaded',
    ]);
  });

  testWidgets('renaming a folder through its menu updates the header', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    folderBloc.emit(
      const ProfileFoldersLoaded(
        ProfileFolderData(folders: <ProfileFolder>[serversFolder]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversFolder.uuid),
        matching: find.byType(PopupMenuButton<PopupMenuEntry>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.folderRename));
    await tester.pumpAndSettle();

    final Finder field = find.byKey(
      const Key('ProfileFolderNameDialog-TextFormField'),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Production');
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Servers'), findsNothing);
    expect(folderRepo.puts.single.folders.single.name, 'Production');
  });

  testWidgets(
    'start and stop buttons line up across headers whatever the title length',
    (WidgetTester tester) async {
      createRealBlocs();
      folderBloc.emit(
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(
                uuid: 'g-short',
                name: 'A',
                profileIds: <String>[sshUuid],
              ),
              ProfileFolder(
                uuid: 'g-long',
                name: 'A much longer folder name than the other one',
                profileIds: <String>[rdpUuid],
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(buildSubject(tester));
      await tester.pump();

      for (final String tooltip in <String>[
        strings.folderStartAll,
        strings.folderStopAll,
      ]) {
        final List<double> xs = tester
            .widgetList(find.byTooltip(tooltip))
            .map((Widget w) => tester.getTopLeft(find.byWidget(w)).dx)
            .toList();
        // Two folders and the unfiled section (which holds noneUuid).
        expect(xs, hasLength(3), reason: tooltip);
        expect(xs.toSet(), hasLength(1), reason: '$tooltip x positions: $xs');
      }
    },
  );

  group('drag and drop', () {
    const ProfileFolder bothFolder = ProfileFolder(
      uuid: 'g-both',
      name: 'Both',
      profileIds: <String>[sshUuid, rdpUuid],
    );
    const Key gripKey = Key('ProfileDragHandle');
    const Key badgeKey = Key('ProfileDragCountBadge');

    Finder grip(Finder item) =>
        find.descendant(of: item, matching: find.byKey(gripKey));

    Future<void> loadFolders(
      WidgetTester tester,
      List<ProfileFolder> folders,
    ) async {
      createRealBlocs();
      folderBloc.emit(
        ProfileFoldersLoaded(ProfileFolderData(folders: folders)),
      );
      await tester.pumpWidget(buildSubject(tester));
      await tester.pump();
    }

    const Duration frame = Duration(milliseconds: 16);

    // Drags from [start] by [dy], then waits out the 250 ms drop animation
    // and the view's 350 ms end timer, pumping frames [dropFrame] apart.
    Future<void> dragFrom(
      WidgetTester tester,
      Offset start,
      double dy, {
      Future<void> Function()? whileDragging,
      Duration dropFrame = frame,
    }) async {
      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      const int steps = 10;
      for (int i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(0, dy / steps));
        await tester.pump(frame);
      }
      await tester.pump(const Duration(milliseconds: 100));
      if (whileDragging != null) await whileDragging();
      await gesture.up();
      for (
        Duration t = Duration.zero;
        t < const Duration(milliseconds: 400);
        t += dropFrame
      ) {
        await tester.pump(dropFrame);
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> dragGrip(
      WidgetTester tester,
      Finder item,
      double dy, {
      Future<void> Function()? whileDragging,
      Duration dropFrame = frame,
    }) async {
      expect(grip(item), findsOneWidget);
      await dragFrom(
        tester,
        tester.getCenter(grip(item)),
        dy,
        whileDragging: whileDragging,
        dropFrame: dropFrame,
      );
    }

    void expectVerticalOrder(WidgetTester tester, List<Finder> finders) {
      for (final Finder f in finders) {
        expect(f, findsOneWidget);
      }
      for (int i = 1; i < finders.length; i++) {
        expect(
          tester.getTopLeft(finders[i - 1]).dy,
          lessThan(tester.getTopLeft(finders[i]).dy),
          reason: '${finders[i - 1]} should be above ${finders[i]}',
        );
      }
    }

    double heightOf(WidgetTester tester, Finder f) => tester.getSize(f).height;

    List<ProfileFolderEvent> dropEvents() => folderBloc.events
        .where(
          (ProfileFolderEvent e) =>
              e is ProfileFolderPlaceProfilesEvent ||
              e is ProfileFolderReorderEvent,
        )
        .toList();

    testWidgets(
      "dragging a row's grip under another folder's header moves it there",
      (WidgetTester tester) async {
        await loadFolders(tester, <ProfileFolder>[
          serversFolder,
          desktopsFolder,
        ]);

        // Proxy bottom lands in the lower half of the Desktops header.
        await dragGrip(
          tester,
          row(sshUuid),
          heightOf(tester, header(desktopsFolder.uuid)) * 0.75,
        );

        expectVerticalOrder(tester, <Finder>[
          header(serversFolder.uuid),
          header(desktopsFolder.uuid),
          row(sshUuid),
          row(rdpUuid),
          header(ProfileFolderListView.unfiledSectionId),
          row(noneUuid),
        ]);
        expect(
          find.descendant(
            of: header(desktopsFolder.uuid),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(
          folderRepo.puts.last,
          const ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(
                uuid: 'g-servers',
                name: 'Servers',
                profileIds: <String>['uuid-not-loaded'],
              ),
              ProfileFolder(
                uuid: 'g-desktops',
                name: 'Desktops',
                profileIds: <String>[sshUuid, rdpUuid],
              ),
            ],
          ),
        );
      },
    );

    testWidgets('dragging a row below its neighbour reorders the folder', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileFolder>[bothFolder]);

      await dragGrip(tester, row(sshUuid), heightOf(tester, row(rdpUuid)));

      expectVerticalOrder(tester, <Finder>[
        header(bothFolder.uuid),
        row(rdpUuid),
        row(sshUuid),
        header(ProfileFolderListView.unfiledSectionId),
        row(noneUuid),
      ]);
      expect(folderRepo.puts, hasLength(1));
      expect(folderRepo.puts.last.folders.single.profileIds, <String>[
        rdpUuid,
        sshUuid,
      ]);
      expect(folderRepo.puts.last.unfiled, isEmpty);
    });

    testWidgets('dragging a row in the flat list stores the unfiled order', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, const <ProfileFolder>[]);
      expect(find.byType(ProfileFolderSectionHeader), findsNothing);

      await dragGrip(
        tester,
        row(noneUuid),
        -heightOf(tester, row(sshUuid)) * 2,
      );

      expectVerticalOrder(tester, <Finder>[
        row(noneUuid),
        row(sshUuid),
        row(rdpUuid),
      ]);
      expect(folderRepo.puts.last.folders, isEmpty);
      expect(folderRepo.puts.last.unfiled, <String>[
        noneUuid,
        sshUuid,
        rdpUuid,
      ]);
    });

    testWidgets("dragging a folder header's grip below another folder "
        'reorders the folders', (WidgetTester tester) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      // Past the ssh row and the Desktops header, so the proxy's bottom sits
      // in the lower half of the rdp row.
      final double dy =
          heightOf(tester, row(sshUuid)) +
          heightOf(tester, header(desktopsFolder.uuid)) +
          heightOf(tester, row(rdpUuid)) * 0.5;
      await dragGrip(
        tester,
        header(serversFolder.uuid),
        dy,
        whileDragging: () async {
          // Rows play no part in a folder drop and are faded meanwhile.
          final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
            find.descendant(
              of: row(noneUuid),
              matching: find.byType(AnimatedOpacity),
            ),
          );
          expect(fade.opacity, lessThan(1));
        },
      );

      expectVerticalOrder(tester, <Finder>[
        header(desktopsFolder.uuid),
        row(rdpUuid),
        header(serversFolder.uuid),
        row(sshUuid),
        header(ProfileFolderListView.unfiledSectionId),
        row(noneUuid),
      ]);
      expect(folderRepo.puts.last.folders, <ProfileFolder>[
        desktopsFolder,
        serversFolder,
      ]);
      final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: row(noneUuid),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.opacity, 1);
    });

    testWidgets('clicking a row checkbox or dragging outside the grip does '
        'not start a drag', (WidgetTester tester) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      final Finder checkbox = find.descendant(
        of: row(sshUuid),
        matching: find.byType(Checkbox),
      );
      await tester.tap(checkbox, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      verify(mockSelectedCubit.select(sshUuid)).called(1);

      final Offset rowTop = tester.getTopLeft(row(sshUuid));
      final double dy = heightOf(tester, header(desktopsFolder.uuid)) * 0.75;
      Future<void> rowStaysPut() async {
        // A lifted row would follow the pointer.
        expect(tester.getTopLeft(row(sshUuid)), rowTop);
      }

      await dragFrom(
        tester,
        tester.getCenter(checkbox),
        dy,
        whileDragging: rowStaysPut,
      );
      await dragFrom(
        tester,
        tester.getCenter(
          find.descendant(
            of: row(sshUuid),
            matching: find.text('Profile $sshUuid'),
          ),
        ),
        dy,
        whileDragging: rowStaysPut,
      );
      final Rect gripRect = tester.getRect(grip(row(sshUuid)));
      await dragFrom(
        tester,
        Offset(gripRect.right + 2, gripRect.center.dy),
        dy,
        whileDragging: rowStaysPut,
      );

      expect(folderRepo.puts, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        header(serversFolder.uuid),
        row(sshUuid),
        header(desktopsFolder.uuid),
        row(rdpUuid),
      ]);
    });

    testWidgets('dragging one of two selected rows shows a count and moves '
        'both', (WidgetTester tester) async {
      when(
        mockSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({sshUuid, noneUuid}));
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);
      expect(find.byKey(badgeKey), findsNothing);

      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsFolder.uuid)) * 0.75,
        whileDragging: () async {
          expect(find.byKey(badgeKey), findsOneWidget);
          expect(
            find.descendant(of: find.byKey(badgeKey), matching: find.text('2')),
            findsOneWidget,
          );
        },
      );

      expect(find.byKey(badgeKey), findsNothing);
      expectVerticalOrder(tester, <Finder>[
        header(serversFolder.uuid),
        header(desktopsFolder.uuid),
        row(sshUuid),
        row(noneUuid),
        row(rdpUuid),
        header(ProfileFolderListView.unfiledSectionId),
      ]);
      expect(folderRepo.puts.last.folders.last.profileIds, <String>[
        sshUuid,
        noneUuid,
        rdpUuid,
      ]);
      expect(folderRepo.puts.last.folders.first.profileIds, <String>[
        'uuid-not-loaded',
      ]);
      expect(folderRepo.puts.last.unfiled, isEmpty);
      verify(mockSelectedCubit.deselectAll()).called(1);
    });

    testWidgets('a selection drop still moves every selected row when the '
        'drop animation runs on slow frames', (WidgetTester tester) async {
      when(
        mockSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({sshUuid, noneUuid}));
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      // 100 ms frames: the drop animation finishes after the view's 350 ms
      // end timer, exercising that race.
      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsFolder.uuid)) * 0.75,
        dropFrame: const Duration(milliseconds: 100),
      );

      expect(folderRepo.puts.last.folders.last.profileIds, <String>[
        sshUuid,
        noneUuid,
        rdpUuid,
      ]);
      verify(mockSelectedCubit.deselectAll()).called(1);
    });

    testWidgets('dragging an unselected row moves it alone and keeps the '
        'selection', (WidgetTester tester) async {
      when(
        mockSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({rdpUuid, noneUuid}));
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsFolder.uuid)) * 0.75,
        whileDragging: () async {
          expect(find.byKey(badgeKey), findsNothing);
        },
      );

      expect(folderRepo.puts.last.folders.last.profileIds, <String>[
        sshUuid,
        rdpUuid,
      ]);
      verifyNever(mockSelectedCubit.deselectAll());
    });

    testWidgets("the folder menu's Move down reorders folders", (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      await tester.tap(
        find.descendant(
          of: header(serversFolder.uuid),
          matching: find.byType(PopupMenuButton<PopupMenuEntry>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.folderMoveDown));
      await tester.pumpAndSettle();

      expectVerticalOrder(tester, <Finder>[
        header(desktopsFolder.uuid),
        row(rdpUuid),
        header(serversFolder.uuid),
        row(sshUuid),
        header(ProfileFolderListView.unfiledSectionId),
      ]);
      expect(folderRepo.puts.single.folders, <ProfileFolder>[
        desktopsFolder,
        serversFolder,
      ]);
    });

    testWidgets(
      'dragging a folder header across its own rows changes nothing',
      (WidgetTester tester) async {
        await loadFolders(tester, <ProfileFolder>[
          serversFolder,
          desktopsFolder,
        ]);
        final List<Finder> inOrder = <Finder>[
          header(serversFolder.uuid),
          row(sshUuid),
          header(desktopsFolder.uuid),
          row(rdpUuid),
          header(ProfileFolderListView.unfiledSectionId),
          row(noneUuid),
        ];
        final double rdpTop = tester.getTopLeft(row(rdpUuid)).dy;

        // Past the rdp row, so the folders keep their order.
        await dragGrip(
          tester,
          header(desktopsFolder.uuid),
          heightOf(tester, row(rdpUuid)) * 0.75,
          whileDragging: () async {
            // The list opened a gap, so this is a real drop.
            expect(tester.getTopLeft(row(rdpUuid)).dy, lessThan(rdpTop));
          },
        );

        expectVerticalOrder(tester, inOrder);
        expect(tester.getTopLeft(row(rdpUuid)).dy, rdpTop);
        expect(dropEvents(), isEmpty);
        expect(folderRepo.puts, isEmpty);
      },
    );

    group('with favorites first', () {
      List<String> rdpFirst(List<String> uuids) => <String>[
        ...uuids.where((String id) => id == rdpUuid),
        ...uuids.where((String id) => id != rdpUuid),
      ];
      int favoritesFirst(ProfileFolder a, ProfileFolder b) =>
          a.favorite == b.favorite ? 0 : (a.favorite ? -1 : 1);

      testWidgets('a drop is saved in the manual order', (
        WidgetTester tester,
      ) async {
        createRealBlocs();
        folderBloc.emit(const ProfileFoldersLoaded(ProfileFolderData()));
        await tester.pumpWidget(buildSubject(tester, arrange: rdpFirst));
        await tester.pump();
        expectVerticalOrder(tester, <Finder>[
          row(rdpUuid),
          row(sshUuid),
          row(noneUuid),
        ]);

        await dragGrip(tester, row(noneUuid), -heightOf(tester, row(sshUuid)));

        expectVerticalOrder(tester, <Finder>[
          row(rdpUuid),
          row(noneUuid),
          row(sshUuid),
        ]);
        expect(folderRepo.puts.single.unfiled, <String>[
          noneUuid,
          sshUuid,
          rdpUuid,
        ]);
      });

      const ProfileFolder otherFolder = ProfileFolder(
        uuid: 'g-other',
        name: 'Other',
        profileIds: <String>[noneUuid],
        favorite: true,
      );

      Future<void> openMenu(WidgetTester tester, ProfileFolder folder) async {
        await tester.tap(
          find.descendant(
            of: header(folder.uuid),
            matching: find.byType(PopupMenuButton<PopupMenuEntry>),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('Move up is saved in the manual order', (
        WidgetTester tester,
      ) async {
        createRealBlocs();
        folderBloc.emit(
          const ProfileFoldersLoaded(
            ProfileFolderData(
              folders: <ProfileFolder>[
                serversFolder,
                desktopsFolder,
                otherFolder,
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(tester, compareFolders: favoritesFirst),
        );
        await tester.pump();

        await openMenu(tester, desktopsFolder);
        await tester.tap(find.text(strings.folderMoveUp));
        await tester.pumpAndSettle();

        expectVerticalOrder(tester, <Finder>[
          header(otherFolder.uuid),
          header(desktopsFolder.uuid),
          header(serversFolder.uuid),
        ]);
        expect(
          folderRepo.puts.single.folders.map((ProfileFolder f) => f.uuid),
          <String>[desktopsFolder.uuid, serversFolder.uuid, otherFolder.uuid],
        );
      });

      testWidgets('Move up is off for the first folder after the favorites', (
        WidgetTester tester,
      ) async {
        createRealBlocs();
        folderBloc.emit(
          const ProfileFoldersLoaded(
            ProfileFolderData(
              folders: <ProfileFolder>[serversFolder, otherFolder],
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(tester, compareFolders: favoritesFirst),
        );
        await tester.pump();

        await openMenu(tester, serversFolder);
        final PopupMenuItem<dynamic> moveUp = tester.widget(
          find.ancestor(
            of: find.text(strings.folderMoveUp),
            matching: find.byType(PopupMenuItem<PopupMenuEntry>),
          ),
        );
        expect(moveUp.enabled, isFalse);
      });

      testWidgets('Move down is off for the last favorite folder', (
        WidgetTester tester,
      ) async {
        createRealBlocs();
        folderBloc.emit(
          const ProfileFoldersLoaded(
            ProfileFolderData(
              folders: <ProfileFolder>[serversFolder, otherFolder],
            ),
          ),
        );
        await tester.pumpWidget(
          buildSubject(tester, compareFolders: favoritesFirst),
        );
        await tester.pump();

        await openMenu(tester, otherFolder);
        PopupMenuItem<dynamic> item(String label) => tester.widget(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(PopupMenuItem<PopupMenuEntry>),
          ),
        );
        // Past a folder that is not a favorite would put it back on top.
        expect(item(strings.folderMoveDown).enabled, isFalse);
        expect(item(strings.folderMoveUp).enabled, isFalse);
      });

      List<String> Function(List<String>) lifting(Set<String> favorites) =>
          (List<String> uuids) => <String>[
            ...uuids.where(favorites.contains),
            ...uuids.where((String id) => !favorites.contains(id)),
          ];

      Future<void> loadUnfiled(
        WidgetTester tester, {
        required List<String> saved,
        required Set<String> favorites,
        List<String> profiles = allUuids,
        String? message,
      }) async {
        createRealBlocs();
        folderBloc.emit(
          ProfileFoldersLoaded(ProfileFolderData(unfiled: saved)),
        );
        await tester.pumpWidget(
          buildSubject(
            tester,
            profiles: profiles,
            arrange: lifting(favorites),
            sortedDropMessage: message,
          ),
        );
        await tester.pump();
      }

      List<String> savedUnfiled() =>
          (folderBloc.state as ProfileFoldersLoaded).data.unfiled;

      testWidgets('dropping a connection above a favorite leaves the saved '
          'order unchanged', (WidgetTester tester) async {
        await loadUnfiled(
          tester,
          saved: <String>[sshUuid, rdpUuid, noneUuid],
          favorites: <String>{rdpUuid},
        );
        final List<Finder> onScreen = <Finder>[
          row(rdpUuid),
          row(sshUuid),
          row(noneUuid),
        ];
        expectVerticalOrder(tester, onScreen);
        final double rdpTop = tester.getTopLeft(row(rdpUuid)).dy;

        await dragGrip(
          tester,
          row(sshUuid),
          -heightOf(tester, row(rdpUuid)),
          whileDragging: () async {
            expect(tester.getTopLeft(row(rdpUuid)).dy, greaterThan(rdpTop));
          },
        );

        // The screen still shows the favorite first.
        expectVerticalOrder(tester, onScreen);
        expect(folderRepo.puts, isEmpty);
        expect(savedUnfiled(), <String>[sshUuid, rdpUuid, noneUuid]);
      });

      testWidgets('dropping a favorite below a connection that is not one '
          'leaves the saved order unchanged', (WidgetTester tester) async {
        await loadUnfiled(
          tester,
          saved: <String>[sshUuid, rdpUuid, noneUuid],
          favorites: <String>{rdpUuid},
        );
        final List<Finder> onScreen = <Finder>[
          row(rdpUuid),
          row(sshUuid),
          row(noneUuid),
        ];
        final double sshTop = tester.getTopLeft(row(sshUuid)).dy;

        await dragGrip(
          tester,
          row(rdpUuid),
          heightOf(tester, row(sshUuid)),
          whileDragging: () async {
            expect(tester.getTopLeft(row(sshUuid)).dy, lessThan(sshTop));
          },
        );

        expectVerticalOrder(tester, onScreen);
        expect(folderRepo.puts, isEmpty);
        expect(savedUnfiled(), <String>[sshUuid, rdpUuid, noneUuid]);
      });

      group('around a connection that is not loaded', () {
        // The saved order has a connection with no row, such as one another
        // device added or one still loading. rdp is a favorite, so the screen
        // shows rdp above ssh whatever the saved order.
        const String hidden = 'uuid-not-loaded';
        const List<String> loadedPair = <String>[sshUuid, rdpUuid];
        final String message = strings.profileSortFavoritesMessage;

        Future<void> dragSshAboveRdp(WidgetTester tester) async {
          final double rdpTop = tester.getTopLeft(row(rdpUuid)).dy;
          await dragGrip(
            tester,
            row(sshUuid),
            -heightOf(tester, row(rdpUuid)),
            whileDragging: () async {
              expect(tester.getTopLeft(row(rdpUuid)).dy, greaterThan(rdpTop));
            },
          );
        }

        testWidgets('dropping a connection above a favorite saves nothing and '
            'says why', (WidgetTester tester) async {
          await loadUnfiled(
            tester,
            saved: <String>[hidden, sshUuid, rdpUuid],
            favorites: <String>{rdpUuid},
            profiles: loadedPair,
            message: message,
          );
          final List<Finder> onScreen = <Finder>[row(rdpUuid), row(sshUuid)];
          expectVerticalOrder(tester, onScreen);

          await dragSshAboveRdp(tester);

          expectVerticalOrder(tester, onScreen);
          expect(dropEvents(), isEmpty);
          expect(folderRepo.puts, isEmpty);
          expect(savedUnfiled(), <String>[hidden, sshUuid, rdpUuid]);
          expect(find.textContaining(message), findsOneWidget);
        });

        testWidgets('the same drop inside a folder saves nothing either', (
          WidgetTester tester,
        ) async {
          const ProfileFolder folder = ProfileFolder(
            uuid: 'g-mixed',
            name: 'Mixed',
            profileIds: <String>[hidden, sshUuid, rdpUuid],
          );
          createRealBlocs();
          folderBloc.emit(
            const ProfileFoldersLoaded(
              ProfileFolderData(folders: <ProfileFolder>[folder]),
            ),
          );
          await tester.pumpWidget(
            buildSubject(
              tester,
              profiles: loadedPair,
              arrange: lifting(<String>{rdpUuid}),
              sortedDropMessage: message,
            ),
          );
          await tester.pump();
          final List<Finder> onScreen = <Finder>[
            header(folder.uuid),
            row(rdpUuid),
            row(sshUuid),
          ];
          expectVerticalOrder(tester, onScreen);

          await dragSshAboveRdp(tester);

          expectVerticalOrder(tester, onScreen);
          expect(dropEvents(), isEmpty);
          expect(folderRepo.puts, isEmpty);
          expect(
            (folderBloc.state as ProfileFoldersLoaded).data.folders.single,
            folder,
          );
          expect(find.textContaining(message), findsOneWidget);
        });

        testWidgets('a drop that changes the order is saved with the hidden '
            'connection kept in front of the one it preceded', (
          WidgetTester tester,
        ) async {
          await loadUnfiled(
            tester,
            saved: <String>[hidden, sshUuid, rdpUuid, noneUuid],
            favorites: <String>{rdpUuid},
            message: message,
          );
          expectVerticalOrder(tester, <Finder>[
            row(rdpUuid),
            row(sshUuid),
            row(noneUuid),
          ]);

          // none goes between rdp and ssh, which the screen can show.
          await dragGrip(
            tester,
            row(noneUuid),
            -heightOf(tester, row(sshUuid)),
          );

          expectVerticalOrder(tester, <Finder>[
            row(rdpUuid),
            row(noneUuid),
            row(sshUuid),
          ]);
          expect(dropEvents(), hasLength(1));
          expect(folderRepo.puts, hasLength(1));
          expect(savedUnfiled(), <String>[noneUuid, hidden, sshUuid, rdpUuid]);
          expect(find.textContaining(message), findsNothing);
        });
      });

      group('a selection of one favorite and one other connection', () {
        // Saved: ssh, none, rdp. On screen the favorites come first: ssh, rdp,
        // none. Moving rdp above ssh changes the saved order; none keeps its
        // place after ssh whichever of the two rows is grabbed.
        const Map<String, int> rowsToTop = <String, int>{
          rdpUuid: 1,
          noneUuid: 2,
        };
        rowsToTop.forEach((String grabbed, int rows) {
          testWidgets('dragged to the top by the ${grabbed.substring(5)} row '
              'is placed per kind', (WidgetTester tester) async {
            when(
              mockSelectedCubit.state,
            ).thenReturn(const ProfilesSelectedState({rdpUuid, noneUuid}));
            await loadUnfiled(
              tester,
              saved: <String>[sshUuid, noneUuid, rdpUuid],
              favorites: <String>{sshUuid, rdpUuid},
            );
            expectVerticalOrder(tester, <Finder>[
              row(sshUuid),
              row(rdpUuid),
              row(noneUuid),
            ]);

            await dragGrip(
              tester,
              row(grabbed),
              -heightOf(tester, row(sshUuid)) * rows,
              whileDragging: () async {
                expect(find.byKey(badgeKey), findsOneWidget);
              },
            );

            expectVerticalOrder(tester, <Finder>[
              row(rdpUuid),
              row(sshUuid),
              row(noneUuid),
            ]);
            expect(folderRepo.puts, hasLength(1));
            expect(savedUnfiled(), <String>[rdpUuid, sshUuid, noneUuid]);
            verify(mockSelectedCubit.deselectAll()).called(1);
          });
        });
      });

      group('dragging a folder header', () {
        // Saved: Servers, Desktops, Other. Other is a favorite, so the screen
        // shows Other, Servers, Desktops.
        Future<void> loadWithFavoriteFolder(
          WidgetTester tester, {
          String? message,
        }) async {
          createRealBlocs();
          folderBloc.emit(
            const ProfileFoldersLoaded(
              ProfileFolderData(
                folders: <ProfileFolder>[
                  serversFolder,
                  desktopsFolder,
                  otherFolder,
                ],
              ),
            ),
          );
          await tester.pumpWidget(
            buildSubject(
              tester,
              compareFolders: favoritesFirst,
              sortedDropMessage: message,
            ),
          );
          await tester.pump();
        }

        List<String> savedFolderIds() =>
            (folderBloc.state as ProfileFoldersLoaded).data.folders
                .map((ProfileFolder f) => f.uuid)
                .toList();

        testWidgets('past another folder of its kind is saved in the manual '
            'order', (WidgetTester tester) async {
          await loadWithFavoriteFolder(tester);
          expectVerticalOrder(tester, <Finder>[
            header(otherFolder.uuid),
            header(serversFolder.uuid),
            header(desktopsFolder.uuid),
          ]);

          // Past the ssh row and the Desktops header, into the rdp row.
          final double dy =
              heightOf(tester, row(sshUuid)) +
              heightOf(tester, header(desktopsFolder.uuid)) +
              heightOf(tester, row(rdpUuid)) * 0.75;
          await dragGrip(tester, header(serversFolder.uuid), dy);

          expectVerticalOrder(tester, <Finder>[
            header(otherFolder.uuid),
            row(noneUuid),
            header(desktopsFolder.uuid),
            row(rdpUuid),
            header(serversFolder.uuid),
            row(sshUuid),
          ]);
          expect(folderRepo.puts, hasLength(1));
          expect(savedFolderIds(), <String>[
            desktopsFolder.uuid,
            serversFolder.uuid,
            otherFolder.uuid,
          ]);
        });

        testWidgets(
          'above a favorite folder leaves the saved order unchanged',
          (WidgetTester tester) async {
            await loadWithFavoriteFolder(tester);
            final double otherTop = tester
                .getTopLeft(header(otherFolder.uuid))
                .dy;

            // Past the none row and into the top half of the Other header.
            final double dy =
                heightOf(tester, row(noneUuid)) +
                heightOf(tester, header(otherFolder.uuid)) * 0.75;
            await dragGrip(
              tester,
              header(serversFolder.uuid),
              -dy,
              whileDragging: () async {
                expect(
                  tester.getTopLeft(header(otherFolder.uuid)).dy,
                  greaterThan(otherTop),
                );
              },
            );

            expectVerticalOrder(tester, <Finder>[
              header(otherFolder.uuid),
              header(serversFolder.uuid),
              header(desktopsFolder.uuid),
            ]);
            expect(folderRepo.puts, isEmpty);
            expect(savedFolderIds(), <String>[
              serversFolder.uuid,
              desktopsFolder.uuid,
              otherFolder.uuid,
            ]);
          },
        );

        testWidgets('past another folder of its kind sends one edit and no '
            'message', (WidgetTester tester) async {
          await loadWithFavoriteFolder(
            tester,
            message: strings.profileSortFavoritesMessage,
          );

          final double dy =
              heightOf(tester, row(sshUuid)) +
              heightOf(tester, header(desktopsFolder.uuid)) +
              heightOf(tester, row(rdpUuid)) * 0.75;
          await dragGrip(tester, header(serversFolder.uuid), dy);

          expect(dropEvents(), hasLength(1));
          expect(folderRepo.puts, hasLength(1));
          expect(
            find.textContaining(strings.profileSortFavoritesMessage),
            findsNothing,
          );
        });

        testWidgets('above a favorite folder sends nothing and says why', (
          WidgetTester tester,
        ) async {
          await loadWithFavoriteFolder(
            tester,
            message: strings.profileSortFavoritesMessage,
          );
          final double otherTop = tester
              .getTopLeft(header(otherFolder.uuid))
              .dy;

          // Past the none row and into the top half of the Other header.
          final double dy =
              heightOf(tester, row(noneUuid)) +
              heightOf(tester, header(otherFolder.uuid)) * 0.75;
          await dragGrip(
            tester,
            header(serversFolder.uuid),
            -dy,
            whileDragging: () async {
              expect(
                tester.getTopLeft(header(otherFolder.uuid)).dy,
                greaterThan(otherTop),
              );
            },
          );

          expect(dropEvents(), isEmpty);
          expect(folderRepo.puts, isEmpty);
          expect(
            find.textContaining(strings.profileSortFavoritesMessage),
            findsOneWidget,
          );
        });

        testWidgets('of a favorite folder below one that is not sends nothing '
            'and says why', (WidgetTester tester) async {
          await loadWithFavoriteFolder(
            tester,
            message: strings.profileSortFavoritesMessage,
          );
          final double serversTop = tester
              .getTopLeft(header(serversFolder.uuid))
              .dy;

          // Past the none row and into the lower half of the Servers header.
          final double dy =
              heightOf(tester, row(noneUuid)) +
              heightOf(tester, header(serversFolder.uuid)) * 0.75;
          await dragGrip(
            tester,
            header(otherFolder.uuid),
            dy,
            whileDragging: () async {
              expect(
                tester.getTopLeft(header(serversFolder.uuid)).dy,
                lessThan(serversTop),
              );
            },
          );

          expect(dropEvents(), isEmpty);
          expect(folderRepo.puts, isEmpty);
          expect(
            find.textContaining(strings.profileSortFavoritesMessage),
            findsOneWidget,
          );
        });

        testWidgets('of a favorite folder below one that is not leaves the '
            'saved order unchanged', (WidgetTester tester) async {
          await loadWithFavoriteFolder(tester);
          final double serversTop = tester
              .getTopLeft(header(serversFolder.uuid))
              .dy;

          // Past the none row and into the lower half of the Servers header.
          final double dy =
              heightOf(tester, row(noneUuid)) +
              heightOf(tester, header(serversFolder.uuid)) * 0.75;
          await dragGrip(
            tester,
            header(otherFolder.uuid),
            dy,
            whileDragging: () async {
              expect(
                tester.getTopLeft(header(serversFolder.uuid)).dy,
                lessThan(serversTop),
              );
            },
          );

          expectVerticalOrder(tester, <Finder>[
            header(otherFolder.uuid),
            header(serversFolder.uuid),
            header(desktopsFolder.uuid),
          ]);
          expect(folderRepo.puts, isEmpty);
          expect(savedFolderIds(), <String>[
            serversFolder.uuid,
            desktopsFolder.uuid,
            otherFolder.uuid,
          ]);
        });
      });
    });

    testWidgets('a lone folder has a grip and the Unfiled header has none', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder]);

      expect(grip(header(serversFolder.uuid)), findsOneWidget);
      expect(
        grip(header(ProfileFolderListView.unfiledSectionId)),
        findsNothing,
      );
      // The rows can still move between the folder and unfiled.
      expect(grip(row(sshUuid)), findsOneWidget);
      expect(grip(row(rdpUuid)), findsOneWidget);
      expect(grip(row(noneUuid)), findsOneWidget);
    });

    testWidgets('a single connection with no folders still has a grip', (
      WidgetTester tester,
    ) async {
      createRealBlocs();
      folderBloc.emit(const ProfileFoldersLoaded(ProfileFolderData()));
      await tester.pumpWidget(
        buildSubject(tester, profiles: const <String>[sshUuid]),
      );
      await tester.pump();

      expect(grip(row(sshUuid)), findsOneWidget);
    });

    testWidgets('with two folders only the folder headers have a grip', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      expect(grip(header(serversFolder.uuid)), findsOneWidget);
      expect(grip(header(desktopsFolder.uuid)), findsOneWidget);
      expect(
        grip(header(ProfileFolderListView.unfiledSectionId)),
        findsNothing,
      );
    });

    testWidgets('no grip exists while folders have not loaded', (
      WidgetTester tester,
    ) async {
      createRealBlocs();
      expect(folderBloc.state, isNot(isA<ProfileFoldersLoaded>()));
      await tester.pumpWidget(buildSubject(tester));
      await tester.pump();

      expect(find.byType(ProfileListRow), findsNWidgets(3));
      expect(find.byKey(gripKey), findsNothing);

      // A drag where the grip would be does nothing.
      await dragFrom(
        tester,
        tester.getTopLeft(row(noneUuid)) + const Offset(22, 20),
        -heightOf(tester, row(sshUuid)) * 2,
      );
      expect(folderRepo.puts, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        row(sshUuid),
        row(rdpUuid),
        row(noneUuid),
      ]);
    });

    group('before the folders have synced', () {
      const ProfileFolderData unsynced = ProfileFolderData(
        folders: <ProfileFolder>[serversFolder, desktopsFolder],
      );

      Future<void> loadUnsynced(WidgetTester tester) async {
        createRealBlocs();
        folderRepo.stored = unsynced;
        folderBloc.emit(const ProfileFoldersLoaded(unsynced, synced: false));
        await tester.pumpWidget(buildSubject(tester));
        await tester.pump();
      }

      Finder toggle(String sectionId, String tooltip) => find.descendant(
        of: header(sectionId),
        matching: find.byTooltip(tooltip),
      );

      testWidgets('there are no grips and a drag where one would be does '
          'nothing', (WidgetTester tester) async {
        await loadUnsynced(tester);

        expect(find.byType(ProfileFolderSectionHeader), findsNWidgets(3));
        expect(find.byType(ProfileListRow), findsNWidgets(3));
        expect(find.byKey(gripKey), findsNothing);

        const Offset gripSpot = Offset(22, 20);
        await dragFrom(
          tester,
          tester.getTopLeft(row(sshUuid)) + gripSpot,
          heightOf(tester, header(desktopsFolder.uuid)) * 0.75,
        );
        await dragFrom(
          tester,
          tester.getTopLeft(header(serversFolder.uuid)) + gripSpot,
          heightOf(tester, row(sshUuid)) * 2,
        );

        expect(folderRepo.puts, isEmpty);
        expect(
          folderBloc.state,
          const ProfileFoldersLoaded(unsynced, synced: false),
        );
        expectVerticalOrder(tester, <Finder>[
          header(serversFolder.uuid),
          row(sshUuid),
          header(desktopsFolder.uuid),
          row(rdpUuid),
          header(ProfileFolderListView.unfiledSectionId),
          row(noneUuid),
        ]);
      });

      testWidgets('the collapse toggle hides and shows the rows of a folder '
          'and of the unfiled section', (WidgetTester tester) async {
        await loadUnsynced(tester);

        await tester.tap(toggle(serversFolder.uuid, strings.folderCollapse));
        await tester.pump();
        expect(row(sshUuid), findsNothing);
        expect(row(rdpUuid), findsOneWidget);
        expect(
          toggle(serversFolder.uuid, strings.folderExpand),
          findsOneWidget,
        );

        await tester.tap(
          toggle(
            ProfileFolderListView.unfiledSectionId,
            strings.folderCollapse,
          ),
        );
        await tester.pump();
        expect(row(noneUuid), findsNothing);

        await tester.tap(toggle(serversFolder.uuid, strings.folderExpand));
        await tester.pump();
        expect(row(sshUuid), findsOneWidget);
        expect(row(noneUuid), findsNothing);
        expect(folderRepo.puts, isEmpty);
      });

      testWidgets('a collapse made meanwhile is saved once they have synced '
          'and the grips appear', (WidgetTester tester) async {
        await loadUnsynced(tester);
        await tester.tap(toggle(serversFolder.uuid, strings.folderCollapse));
        await tester.pump();
        expect(folderRepo.puts, isEmpty);

        folderBloc.add(const ProfileFolderRefreshEvent(caughtUp: true));
        await tester.pumpAndSettle();

        expect(folderRepo.puts, hasLength(1));
        expect(
          folderRepo.puts.single.folders.map((ProfileFolder f) => f.collapsed),
          <bool>[true, false],
        );
        expect((folderBloc.state as ProfileFoldersLoaded).synced, isTrue);
        expect(row(sshUuid), findsNothing);
        expect(grip(header(serversFolder.uuid)), findsOneWidget);
        expect(grip(row(rdpUuid)), findsOneWidget);
      });
    });

    testWidgets('every grip is ProfileDragHandle.width wide and rows and '
        'headers share its column', (WidgetTester tester) async {
      await loadFolders(tester, <ProfileFolder>[serversFolder, desktopsFolder]);

      final List<Finder> items = <Finder>[
        row(sshUuid),
        row(rdpUuid),
        row(noneUuid),
        header(serversFolder.uuid),
        header(desktopsFolder.uuid),
      ];
      final double left = tester.getTopLeft(grip(row(sshUuid))).dx;
      for (final Finder item in items) {
        expect(tester.getSize(grip(item)).width, ProfileDragHandle.width);
        expect(tester.getTopLeft(grip(item)).dx, left);
      }
      expect(ProfileDragHandle.width, 24);
    });

    testWidgets(
      'an empty Unfiled section is hidden until a connection is dragged, '
      'and takes a dropped connection out of its folder',
      (WidgetTester tester) async {
        const ProfileFolder allFolder = ProfileFolder(
          uuid: 'g-all',
          name: 'All',
          profileIds: <String>[sshUuid, rdpUuid, noneUuid],
        );
        await loadFolders(tester, <ProfileFolder>[allFolder]);
        final Finder unfiled = header(ProfileFolderListView.unfiledSectionId);
        expect(heightOf(tester, unfiled), 0);

        double? heightWhileDragging;
        await dragGrip(
          tester,
          row(noneUuid),
          80,
          whileDragging: () async {
            heightWhileDragging = heightOf(tester, unfiled);
          },
        );

        expect(heightWhileDragging, greaterThan(0));
        expect(heightOf(tester, unfiled), greaterThan(0));
        expectVerticalOrder(tester, <Finder>[
          header(allFolder.uuid),
          row(sshUuid),
          row(rdpUuid),
          unfiled,
          row(noneUuid),
        ]);
        expect(
          folderRepo.puts.last,
          const ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(
                uuid: 'g-all',
                name: 'All',
                profileIds: <String>[sshUuid, rdpUuid],
              ),
            ],
            unfiled: <String>[noneUuid],
          ),
        );
      },
    );
  });

  group('scroll position', () {
    // 40 connections: the first ten in a folder, the rest unfiled.
    final List<String> many = <String>[
      for (int i = 0; i < 40; i++) 'uuid-many-$i',
    ];
    final ProfileFolderData manyData = ProfileFolderData(
      folders: <ProfileFolder>[
        ProfileFolder(
          uuid: 'g-first',
          name: 'First',
          profileIds: many.take(10).toList(),
        ),
      ],
    );
    const Key gripKey = Key('ProfileDragHandle');

    void stubProfiles(List<String> uuids) {
      for (final String uuid in uuids) {
        final MockProfileBloc bloc = MockProfileBloc();
        final ProfileState state = ProfileLoaded(
          uuid,
          profile: buildProfile(uuid, 'ssh'),
        );
        when(bloc.uuid).thenReturn(uuid);
        when(bloc.state).thenReturn(state);
        when(bloc.stream).thenAnswer((_) => Stream<ProfileState>.value(state));
        when(mockCache.getProfileBloc(uuid)).thenReturn(bloc);
        profileBlocs[uuid] = bloc;
      }
    }

    Future<void> load(WidgetTester tester, {required bool synced}) async {
      stubProfiles(many);
      createRealBlocs();
      folderBloc.emit(ProfileFoldersLoaded(manyData, synced: synced));
      await tester.pumpWidget(buildSubject(tester, profiles: many));
      await tester.pump();
    }

    // What a search shows: no reordering and no moves, whatever the sort.
    Future<void> setSearching(WidgetTester tester, bool searching) async {
      await tester.pumpWidget(
        buildSubject(
          tester,
          profiles: many,
          searching: searching,
          reorderable: !searching,
          movable: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    final Finder list = find.byWidgetPredicate(
      (Widget w) => w is ListView || w is ReorderableListView,
    );
    Finder row(String uuid) =>
        find.byKey(ValueKey<String>('ProfileListRow-$uuid'));

    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;

    Future<void> scrollBy(WidgetTester tester, double dy) async {
      await tester.drag(list, Offset(0, -dy));
      await tester.pumpAndSettle();
    }

    String firstShown(WidgetTester tester) => tester
        .widgetList<ProfileListRow>(find.byType(ProfileListRow))
        .firstWhere(
          (ProfileListRow r) => tester.getTopLeft(row(r.uuid)).dy >= 0,
        )
        .uuid;

    testWidgets('survives the switch from the read-only list to the '
        'reorderable one when the folders sync', (WidgetTester tester) async {
      await load(tester, synced: false);
      expect(tester.widget(list), isA<ListView>());
      expect(find.byKey(gripKey), findsNothing);

      await scrollBy(tester, 900);
      final double scrolled = offset(tester);
      expect(scrolled, greaterThan(500));
      final String anchor = firstShown(tester);
      final double anchorTop = tester.getTopLeft(row(anchor)).dy;

      folderBloc.emit(ProfileFoldersLoaded(manyData));
      await tester.pumpAndSettle();

      // A different list took over, and it starts where the other stopped.
      expect(tester.widget(list), isA<ReorderableListView>());
      expect(find.byKey(gripKey), findsWidgets);
      expect(offset(tester), scrolled);
      expect(tester.getTopLeft(row(anchor)).dy, anchorTop);
    });

    testWidgets('survives the folders loading after the flat list', (
      WidgetTester tester,
    ) async {
      stubProfiles(many);
      createRealBlocs();
      await tester.pumpWidget(buildSubject(tester, profiles: many));
      await tester.pump();
      expect(folderBloc.state, isA<ProfileFoldersInitial>());
      expect(tester.widget(list), isA<ListView>());

      await scrollBy(tester, 900);
      final double scrolled = offset(tester);
      expect(scrolled, greaterThan(500));

      // No list is shown while they load.
      folderBloc.emit(const ProfileFoldersLoading());
      await tester.pump(const Duration(milliseconds: 50));
      expect(list, findsNothing);

      folderBloc.emit(ProfileFoldersLoaded(manyData, synced: false));
      await tester.pumpAndSettle();

      expect(offset(tester), scrolled);
    });

    testWidgets('survives a search starting and ending', (
      WidgetTester tester,
    ) async {
      await load(tester, synced: true);
      expect(tester.widget(list), isA<ReorderableListView>());

      await scrollBy(tester, 700);
      final double beforeSearch = offset(tester);
      expect(beforeSearch, greaterThan(400));

      await setSearching(tester, true);

      expect(tester.widget(list), isA<ListView>());
      expect(find.byKey(gripKey), findsNothing);
      expect(offset(tester), beforeSearch);

      // Scrolled further while searching, and the list keeps that on its way
      // back.
      await scrollBy(tester, 300);
      final double duringSearch = offset(tester);
      expect(duringSearch, greaterThan(beforeSearch));

      await setSearching(tester, false);

      expect(tester.widget(list), isA<ReorderableListView>());
      expect(find.byKey(gripKey), findsWidgets);
      expect(offset(tester), duringSearch);
    });

    testWidgets('a search that starts while the folders are unsynced keeps it '
        'too', (WidgetTester tester) async {
      await load(tester, synced: false);
      await scrollBy(tester, 900);
      final double scrolled = offset(tester);
      expect(scrolled, greaterThan(500));

      await setSearching(tester, true);
      expect(offset(tester), scrolled);

      folderBloc.emit(ProfileFoldersLoaded(manyData));
      await tester.pumpAndSettle();
      expect(offset(tester), scrolled);

      await setSearching(tester, false);
      expect(tester.widget(list), isA<ReorderableListView>());
      expect(offset(tester), scrolled);
    });
  });
}
