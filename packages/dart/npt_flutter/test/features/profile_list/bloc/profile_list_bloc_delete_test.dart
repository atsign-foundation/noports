import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';

import '../../profile/bloc/profile_bloc_test.mocks.dart' as profile_mocks;
import '../view/profile_list_view_test.mocks.dart' show MockFavoriteBloc;

class _FakeProfileFolderRepository extends ProfileFolderRepository {
  ProfileFolderData stored = const ProfileFolderData(
    folders: <ProfileFolder>[
      ProfileFolder(
        uuid: 'g-servers',
        name: 'Servers',
        profileIds: <String>['p1', 'p2'],
      ),
    ],
  );

  @override
  Future<ProfileFolderData?> getProfileFolders() async => stored;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    stored = data;
    return true;
  }

  @override
  Future<bool> waitForSync({
    Duration timeout = const Duration(seconds: 30),
  }) async => true;

  @override
  void watchSync(void Function(bool caughtUp) onRound) {}

  @override
  void stopWatching() {}
}

/// Loaded, and never reports how a start ends, so the queue keeps waiting.
class _IdleProfileBloc extends Fake implements ProfileBloc {
  _IdleProfileBloc(this.uuid);

  @override
  final String uuid;

  final StreamController<ProfileState> _states =
      StreamController<ProfileState>.broadcast();

  @override
  ProfileState get state => ProfileLoaded(
    uuid,
    profile: Profile(
      uuid,
      displayName: uuid,
      deviceName: 'device',
      remotePort: 22,
      localPort: 0,
    ),
  );

  @override
  Stream<ProfileState> get stream => _states.stream;

  @override
  bool get isClosed => false;

  @override
  void add(ProfileEvent event) {}
}

class _IdleProfileCache extends Fake implements ProfileCacheCubit {
  final Map<String, _IdleProfileBloc> _blocs = <String, _IdleProfileBloc>{};

  @override
  ProfileBloc getProfileBloc(String uuid) =>
      _blocs.putIfAbsent(uuid, () => _IdleProfileBloc(uuid));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileListBloc listBloc;
  late ProfileFolderBloc folderBloc;
  late _FakeProfileFolderRepository folderRepo;
  late ProfileStartQueueCubit queue;

  Future<void> pumpApp(WidgetTester tester) async {
    provideDummy<FavoritesState>(const FavoritesInitial());
    final profile_mocks.MockProfileRepository profileRepo =
        profile_mocks.MockProfileRepository();
    when(profileRepo.deleteProfile(any)).thenAnswer((_) async => true);
    final MockFavoriteBloc favorites = MockFavoriteBloc();
    when(favorites.state).thenReturn(const FavoritesLoaded([]));
    when(
      favorites.stream,
    ).thenAnswer((_) => const Stream<FavoritesState>.empty());
    listBloc = ProfileListBloc(profileRepo);
    folderRepo = _FakeProfileFolderRepository();
    folderBloc = ProfileFolderBloc(folderRepo);
    queue = ProfileStartQueueCubit(_IdleProfileCache());
    addTearDown(() async {
      await listBloc.close();
      await folderBloc.close();
      await queue.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<EnableLoggingCubit>(
            create: (_) => EnableLoggingCubit()..disable(),
          ),
          BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
          BlocProvider<FavoriteBloc>.value(value: favorites),
          BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
          BlocProvider<ProfileStartQueueCubit>.value(value: queue),
        ],
        child: MaterialApp(navigatorKey: App.navState, home: const SizedBox()),
      ),
    );
    folderBloc.add(const ProfileFolderLoadEvent());
    listBloc.add(const ProfileListUpdateEvent(<String>['p1', 'p2']));
    await tester.pump();
    await tester.pump();
    expect(folderBloc.state.editable, isTrue);
    expect(listBloc.state, isA<ProfileListLoaded>());
  }

  group('deleting a connection', () {
    testWidgets('takes it out of its folder', (WidgetTester tester) async {
      await pumpApp(tester);

      listBloc.add(const ProfileListDeleteEvent(toDelete: <String>['p1']));
      await tester.pump();
      await tester.pump();

      final ProfileFolderData shown =
          (folderBloc.state as ProfileFoldersLoaded).data;
      expect(shown.folderById('g-servers')!.profileIds, <String>['p2']);
      expect(folderRepo.stored.folderById('g-servers')!.profileIds, <String>[
        'p2',
      ]);
    });

    testWidgets('takes it out of the start queue', (WidgetTester tester) async {
      await pumpApp(tester);
      queue.add(<String>['p2', 'p1']);
      await tester.pump();
      expect(queue.state.waiting, <String>['p1']);

      listBloc.add(const ProfileListDeleteEvent(toDelete: <String>['p1']));
      await tester.pump();

      expect(queue.state.waiting, isEmpty);
      await tester.pump(const Duration(minutes: 2));
    });
  });
}
