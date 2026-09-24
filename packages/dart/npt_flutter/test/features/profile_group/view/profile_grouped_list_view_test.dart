import 'package:at_client/at_client.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/language.dart';

import '../../profile_list/view/profile_list_view_test.mocks.dart';

class FakeProfileGroupRepository extends ProfileGroupRepository {
  final List<ProfileGroupData> puts = <ProfileGroupData>[];

  @override
  Future<ProfileGroupData?> getProfileGroups() async => null;

  @override
  Future<bool> putProfileGroups(ProfileGroupData data) async {
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

  const ProfileGroup serversGroup = ProfileGroup(
    uuid: 'g-servers',
    name: 'Servers',
    profileIds: <String>[sshUuid, 'uuid-not-loaded'],
  );
  const ProfileGroup desktopsGroup = ProfileGroup(
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
  late FakeProfileGroupRepository groupRepo;
  late ProfileGroupBloc groupBloc;

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
    groupRepo = FakeProfileGroupRepository();
    groupBloc = ProfileGroupBloc(groupRepo);
    addTearDown(() async {
      await runningCubit.close();
      await groupBloc.close();
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
        BlocProvider<ProfileGroupBloc>.value(value: groupBloc),
        BlocProvider<ProfileListBloc>.value(value: mockListBloc),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ProfileGroupedListView(profiles: profiles)),
      ),
    );
  }

  Finder header(String id) =>
      find.byKey(ValueKey<String>('ProfileGroupSectionHeader-$id'));
  Finder row(String uuid) =>
      find.byKey(ValueKey<String>('ProfileListRow-$uuid'));

  testWidgets('renders a flat list while groups have not loaded', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(find.byType(ProfileGroupSectionHeader), findsNothing);
  });

  testWidgets('renders a flat list when loaded without any folders', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    groupBloc.emit(const ProfileGroupsLoaded(ProfileGroupData()));
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(find.byType(ProfileGroupSectionHeader), findsNothing);
  });

  testWidgets('renders folders in order followed by the ungrouped section', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[serversGroup, desktopsGroup]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    expect(header(serversGroup.uuid), findsOneWidget);
    expect(header(desktopsGroup.uuid), findsOneWidget);
    expect(header(ProfileGroupedListView.ungroupedSectionId), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('Desktops'), findsOneWidget);
    expect(find.text(strings.groupUngrouped), findsOneWidget);
    expect(find.byType(ProfileListRow), findsNWidgets(3));

    // Profile ids that are not loaded do not count towards the folder.
    final Finder serversCount = find.descendant(
      of: header(serversGroup.uuid),
      matching: find.text('1'),
    );
    expect(serversCount, findsOneWidget);

    // Vertical order: Servers, ssh row, Desktops, rdp row, Ungrouped, none row.
    final double serversY = tester.getTopLeft(header(serversGroup.uuid)).dy;
    final double sshY = tester.getTopLeft(row(sshUuid)).dy;
    final double desktopsY = tester.getTopLeft(header(desktopsGroup.uuid)).dy;
    final double rdpY = tester.getTopLeft(row(rdpUuid)).dy;
    final double ungroupedY = tester
        .getTopLeft(header(ProfileGroupedListView.ungroupedSectionId))
        .dy;
    final double noneY = tester.getTopLeft(row(noneUuid)).dy;
    expect(serversY, lessThan(sshY));
    expect(sshY, lessThan(desktopsY));
    expect(desktopsY, lessThan(rdpY));
    expect(rdpY, lessThan(ungroupedY));
    expect(ungroupedY, lessThan(noneY));
  });

  testWidgets('collapsing a folder hides its rows only', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[serversGroup, desktopsGroup]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversGroup.uuid),
        matching: find.byTooltip(strings.groupCollapse),
      ),
    );
    await tester.pump();

    expect(row(sshUuid), findsNothing);
    expect(row(rdpUuid), findsOneWidget);
    expect(row(noneUuid), findsOneWidget);
    expect(
      find.descendant(
        of: header(serversGroup.uuid),
        matching: find.byTooltip(strings.groupExpand),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'start all sends ProfileStartEvent to each profile in the folder',
    (WidgetTester tester) async {
      createRealBlocs();
      groupBloc.emit(
        const ProfileGroupsLoaded(
          ProfileGroupData(groups: <ProfileGroup>[serversGroup, desktopsGroup]),
        ),
      );
      await tester.pumpWidget(buildSubject(tester));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: header(serversGroup.uuid),
          matching: find.byTooltip(strings.groupStartAll),
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
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[serversGroup]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    Finder stopButton() => find.descendant(
      of: header(serversGroup.uuid),
      matching: find.ancestor(
        of: find.byTooltip(strings.groupStopAll),
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
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[serversGroup, desktopsGroup]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversGroup.uuid),
        matching: find.byType(PopupMenuButton<PopupMenuEntry>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.groupDeleteFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(header(serversGroup.uuid), findsNothing);
    expect(header(desktopsGroup.uuid), findsOneWidget);
    expect(header(ProfileGroupedListView.ungroupedSectionId), findsOneWidget);
    expect(find.byType(ProfileListRow), findsNWidgets(3));
    expect(groupRepo.puts.single.groups, <ProfileGroup>[desktopsGroup]);
    // The folder's members go after what ungrouped already showed.
    expect(groupRepo.puts.single.ungrouped, <String>[
      noneUuid,
      sshUuid,
      'uuid-not-loaded',
    ]);
  });

  testWidgets('renaming a folder through its menu updates the header', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[serversGroup]),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: header(serversGroup.uuid),
        matching: find.byType(PopupMenuButton<PopupMenuEntry>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.groupRename));
    await tester.pumpAndSettle();

    final Finder field = find.byKey(
      const Key('ProfileGroupNameDialog-TextFormField'),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Production');
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Servers'), findsNothing);
    expect(groupRepo.puts.single.groups.single.name, 'Production');
  });

  testWidgets(
    'start and stop buttons line up across headers whatever the title length',
    (WidgetTester tester) async {
      createRealBlocs();
      groupBloc.emit(
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(
                uuid: 'g-short',
                name: 'A',
                profileIds: <String>[sshUuid],
              ),
              ProfileGroup(
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
        strings.groupStartAll,
        strings.groupStopAll,
      ]) {
        final List<double> xs = tester
            .widgetList(find.byTooltip(tooltip))
            .map((Widget w) => tester.getTopLeft(find.byWidget(w)).dx)
            .toList();
        // Two folders and the ungrouped section (which holds noneUuid).
        expect(xs, hasLength(3), reason: tooltip);
        expect(xs.toSet(), hasLength(1), reason: '$tooltip x positions: $xs');
      }
    },
  );

  group('drag and drop', () {
    const ProfileGroup bothGroup = ProfileGroup(
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
      List<ProfileGroup> groups,
    ) async {
      createRealBlocs();
      groupBloc.emit(ProfileGroupsLoaded(ProfileGroupData(groups: groups)));
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
        await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

        // Proxy bottom lands in the lower half of the Desktops header.
        await dragGrip(
          tester,
          row(sshUuid),
          heightOf(tester, header(desktopsGroup.uuid)) * 0.75,
        );

        expectVerticalOrder(tester, <Finder>[
          header(serversGroup.uuid),
          header(desktopsGroup.uuid),
          row(sshUuid),
          row(rdpUuid),
          header(ProfileGroupedListView.ungroupedSectionId),
          row(noneUuid),
        ]);
        expect(
          find.descendant(
            of: header(desktopsGroup.uuid),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(
          groupRepo.puts.last,
          const ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(
                uuid: 'g-servers',
                name: 'Servers',
                profileIds: <String>['uuid-not-loaded'],
              ),
              ProfileGroup(
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
      await loadFolders(tester, <ProfileGroup>[bothGroup]);

      await dragGrip(tester, row(sshUuid), heightOf(tester, row(rdpUuid)));

      expectVerticalOrder(tester, <Finder>[
        header(bothGroup.uuid),
        row(rdpUuid),
        row(sshUuid),
        header(ProfileGroupedListView.ungroupedSectionId),
        row(noneUuid),
      ]);
      expect(groupRepo.puts, hasLength(1));
      expect(groupRepo.puts.last.groups.single.profileIds, <String>[
        rdpUuid,
        sshUuid,
      ]);
      expect(groupRepo.puts.last.ungrouped, isEmpty);
    });

    testWidgets('dragging a row in the flat list stores the ungrouped order', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, const <ProfileGroup>[]);
      expect(find.byType(ProfileGroupSectionHeader), findsNothing);

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
      expect(groupRepo.puts.last.groups, isEmpty);
      expect(groupRepo.puts.last.ungrouped, <String>[
        noneUuid,
        sshUuid,
        rdpUuid,
      ]);
    });

    testWidgets("dragging a folder header's grip below another folder "
        'reorders the folders', (WidgetTester tester) async {
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      // Past the ssh row and the Desktops header, so the proxy's bottom sits
      // in the lower half of the rdp row.
      final double dy =
          heightOf(tester, row(sshUuid)) +
          heightOf(tester, header(desktopsGroup.uuid)) +
          heightOf(tester, row(rdpUuid)) * 0.5;
      await dragGrip(
        tester,
        header(serversGroup.uuid),
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
        header(desktopsGroup.uuid),
        row(rdpUuid),
        header(serversGroup.uuid),
        row(sshUuid),
        header(ProfileGroupedListView.ungroupedSectionId),
        row(noneUuid),
      ]);
      expect(groupRepo.puts.last.groups, <ProfileGroup>[
        desktopsGroup,
        serversGroup,
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
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      final Finder checkbox = find.descendant(
        of: row(sshUuid),
        matching: find.byType(Checkbox),
      );
      await tester.tap(checkbox, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      verify(mockSelectedCubit.select(sshUuid)).called(1);

      final Offset rowTop = tester.getTopLeft(row(sshUuid));
      final double dy = heightOf(tester, header(desktopsGroup.uuid)) * 0.75;
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

      expect(groupRepo.puts, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        header(serversGroup.uuid),
        row(sshUuid),
        header(desktopsGroup.uuid),
        row(rdpUuid),
      ]);
    });

    testWidgets('dragging one of two selected rows shows a count and moves '
        'both', (WidgetTester tester) async {
      when(
        mockSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({sshUuid, noneUuid}));
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);
      expect(find.byKey(badgeKey), findsNothing);

      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsGroup.uuid)) * 0.75,
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
        header(serversGroup.uuid),
        header(desktopsGroup.uuid),
        row(sshUuid),
        row(noneUuid),
        row(rdpUuid),
        header(ProfileGroupedListView.ungroupedSectionId),
      ]);
      expect(groupRepo.puts.last.groups.last.profileIds, <String>[
        sshUuid,
        noneUuid,
        rdpUuid,
      ]);
      expect(groupRepo.puts.last.groups.first.profileIds, <String>[
        'uuid-not-loaded',
      ]);
      expect(groupRepo.puts.last.ungrouped, isEmpty);
      verify(mockSelectedCubit.deselectAll()).called(1);
    });

    testWidgets('a selection drop still moves every selected row when the '
        'drop animation runs on slow frames', (WidgetTester tester) async {
      when(
        mockSelectedCubit.state,
      ).thenReturn(const ProfilesSelectedState({sshUuid, noneUuid}));
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      // 100 ms frames: the drop animation finishes after the view's 350 ms
      // end timer, exercising that race.
      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsGroup.uuid)) * 0.75,
        dropFrame: const Duration(milliseconds: 100),
      );

      expect(groupRepo.puts.last.groups.last.profileIds, <String>[
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
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      await dragGrip(
        tester,
        row(sshUuid),
        heightOf(tester, header(desktopsGroup.uuid)) * 0.75,
        whileDragging: () async {
          expect(find.byKey(badgeKey), findsNothing);
        },
      );

      expect(groupRepo.puts.last.groups.last.profileIds, <String>[
        sshUuid,
        rdpUuid,
      ]);
      verifyNever(mockSelectedCubit.deselectAll());
    });

    testWidgets("the folder menu's Move down reorders folders", (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      await tester.tap(
        find.descendant(
          of: header(serversGroup.uuid),
          matching: find.byType(PopupMenuButton<PopupMenuEntry>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.groupMoveDown));
      await tester.pumpAndSettle();

      expectVerticalOrder(tester, <Finder>[
        header(desktopsGroup.uuid),
        row(rdpUuid),
        header(serversGroup.uuid),
        row(sshUuid),
        header(ProfileGroupedListView.ungroupedSectionId),
      ]);
      expect(groupRepo.puts.single.groups, <ProfileGroup>[
        desktopsGroup,
        serversGroup,
      ]);
    });

    testWidgets('a lone folder has a grip and the Ungrouped header has none', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileGroup>[serversGroup]);

      expect(grip(header(serversGroup.uuid)), findsOneWidget);
      expect(
        grip(header(ProfileGroupedListView.ungroupedSectionId)),
        findsNothing,
      );
      // The rows can still move between the folder and ungrouped.
      expect(grip(row(sshUuid)), findsOneWidget);
      expect(grip(row(rdpUuid)), findsOneWidget);
      expect(grip(row(noneUuid)), findsOneWidget);
    });

    testWidgets('a single connection with no folders still has a grip', (
      WidgetTester tester,
    ) async {
      createRealBlocs();
      groupBloc.emit(const ProfileGroupsLoaded(ProfileGroupData()));
      await tester.pumpWidget(
        buildSubject(tester, profiles: const <String>[sshUuid]),
      );
      await tester.pump();

      expect(grip(row(sshUuid)), findsOneWidget);
    });

    testWidgets('with two folders only the folder headers have a grip', (
      WidgetTester tester,
    ) async {
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      expect(grip(header(serversGroup.uuid)), findsOneWidget);
      expect(grip(header(desktopsGroup.uuid)), findsOneWidget);
      expect(
        grip(header(ProfileGroupedListView.ungroupedSectionId)),
        findsNothing,
      );
    });

    testWidgets('no grip exists while folders have not loaded', (
      WidgetTester tester,
    ) async {
      createRealBlocs();
      expect(groupBloc.state, isNot(isA<ProfileGroupsLoaded>()));
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
      expect(groupRepo.puts, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        row(sshUuid),
        row(rdpUuid),
        row(noneUuid),
      ]);
    });

    testWidgets('every grip is ProfileDragHandle.width wide and rows and '
        'headers share its column', (WidgetTester tester) async {
      await loadFolders(tester, <ProfileGroup>[serversGroup, desktopsGroup]);

      final List<Finder> items = <Finder>[
        row(sshUuid),
        row(rdpUuid),
        row(noneUuid),
        header(serversGroup.uuid),
        header(desktopsGroup.uuid),
      ];
      final double left = tester.getTopLeft(grip(row(sshUuid))).dx;
      for (final Finder item in items) {
        expect(tester.getSize(grip(item)).width, ProfileDragHandle.width);
        expect(tester.getTopLeft(grip(item)).dx, left);
      }
      expect(ProfileDragHandle.width, 24);
    });

    testWidgets(
      'an empty Ungrouped section is hidden until a connection is dragged, '
      'and takes a dropped connection out of its folder',
      (WidgetTester tester) async {
        const ProfileGroup allGroup = ProfileGroup(
          uuid: 'g-all',
          name: 'All',
          profileIds: <String>[sshUuid, rdpUuid, noneUuid],
        );
        await loadFolders(tester, <ProfileGroup>[allGroup]);
        final Finder ungrouped = header(
          ProfileGroupedListView.ungroupedSectionId,
        );
        expect(heightOf(tester, ungrouped), 0);

        double? heightWhileDragging;
        await dragGrip(
          tester,
          row(noneUuid),
          80,
          whileDragging: () async {
            heightWhileDragging = heightOf(tester, ungrouped);
          },
        );

        expect(heightWhileDragging, greaterThan(0));
        expect(heightOf(tester, ungrouped), greaterThan(0));
        expectVerticalOrder(tester, <Finder>[
          header(allGroup.uuid),
          row(sshUuid),
          row(rdpUuid),
          ungrouped,
          row(noneUuid),
        ]);
        expect(
          groupRepo.puts.last,
          const ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(
                uuid: 'g-all',
                name: 'All',
                profileIds: <String>[sshUuid, rdpUuid],
              ),
            ],
            ungrouped: <String>[noneUuid],
          ),
        );
      },
    );
  });
}
