import 'package:at_client/at_client.dart';
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

  Widget buildSubject(WidgetTester tester) {
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
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ProfileGroupedListView(profiles: allUuids)),
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

  testWidgets('group by type buckets profiles by their protocol', (
    WidgetTester tester,
  ) async {
    createRealBlocs();
    groupBloc.emit(
      const ProfileGroupsLoaded(
        ProfileGroupData(
          groups: <ProfileGroup>[serversGroup],
          sortByType: true,
        ),
      ),
    );
    await tester.pumpWidget(buildSubject(tester));
    await tester.pump();

    // Custom folders are hidden while grouping by type.
    expect(header(serversGroup.uuid), findsNothing);
    expect(header('type-ssh'), findsOneWidget);
    expect(header('type-rdp'), findsOneWidget);
    expect(header('type-none'), findsOneWidget);
    expect(header('type-http'), findsNothing);
    expect(header('type-vnc'), findsNothing);
    expect(find.text(strings.groupTypeSsh), findsOneWidget);
    expect(find.text(strings.groupTypeRdp), findsOneWidget);
    expect(find.text(strings.groupTypeNone), findsOneWidget);

    final double sshHeaderY = tester.getTopLeft(header('type-ssh')).dy;
    final double sshRowY = tester.getTopLeft(row(sshUuid)).dy;
    final double rdpHeaderY = tester.getTopLeft(header('type-rdp')).dy;
    expect(sshHeaderY, lessThan(sshRowY));
    expect(sshRowY, lessThan(rdpHeaderY));
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
}
