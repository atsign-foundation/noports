import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/gestures.dart';
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
  late ProfileFolderBloc folderBloc;

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

  /// The real blocs must be created inside the test body so that their stream
  /// subscriptions live in the FakeAsync zone driven by [WidgetTester.pump].
  void createRealBlocs() {
    runningCubit = ProfilesRunningCubit();
    folderRepo = FakeProfileFolderRepository();
    folderBloc = ProfileFolderBloc(folderRepo);
    addTearDown(() async {
      await runningCubit.close();
      await folderBloc.close();
    });
  }

  Widget buildSubject(WidgetTester tester, {List<String> profiles = allUuids}) {
    tester.view.physicalSize = const Size(1053, 691);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileCacheCubit>.value(value: mockCache),
        BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
        BlocProvider<ProfilesSelectedCubit>.value(value: mockSelectedCubit),
        BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
        BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
        BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
        BlocProvider<ProfileListBloc>.value(value: mockListBloc),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ProfileFolderListView(profiles: profiles)),
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

    /// Drags from [start] by [dy], then waits out the 250 ms drop animation
    /// and the view's 350 ms end timer, pumping frames [dropFrame] apart.
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
}
