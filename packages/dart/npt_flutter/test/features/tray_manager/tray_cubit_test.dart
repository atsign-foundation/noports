import 'dart:async';

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
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/tray_manager/tray_manager.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../favorite/bloc/favorite_bloc_test.mocks.dart';
import '../profile/bloc/profile_bloc_test.mocks.dart';
import 'tray_favorite_folders_test.dart' show FakeProfileFolderRepository;

/// A [FavoriteBloc] pinned to one state - the tray only reads `.state`.
class _FixedFavoriteBloc extends FavoriteBloc {
  _FixedFavoriteBloc(this.fixed) : super(MockFavoriteRepository());

  final FavoritesState fixed;

  @override
  FavoritesState get state => fixed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uuid = 'profile-uuid';
  final profile = Profile(
    uuid,
    displayName: 'Old name',
    sshnpdAtsign: '@device'.toAtsign(),
    deviceName: 'desktop',
    remotePort: 3389,
    localPort: 0,
    relayAtsign: '@relay'.toAtsign(),
  );

  /// The labels of each menu the tray was given, in order.
  final menus = <List<String>>[];

  setUp(() {
    menus.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('tray_manager'), (
          call,
        ) async {
          if (call.method == 'setContextMenu') {
            final items = (call.arguments as Map)['menu']['items'] as List;
            menus.add([for (final item in items) (item as Map)['label']]);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('tray_manager'), null);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('Given a tray reload still waiting on a favourite\'s name', () {
    testWidgets('when a later reload finishes first, then the tray keeps the '
        'later menu', (tester) async {
      final repository = MockProfileRepository();
      final firstName = Completer<Profile?>();
      when(repository.getProfile(uuid)).thenAnswer((_) => firstName.future);
      final listBloc = ProfileListBloc(repository);
      final cache = ProfileCacheCubit(repository);
      final trayCubit = TrayCubit();
      addTearDown(listBloc.close);
      addTearDown(cache.close);
      addTearDown(trayCubit.close);

      await tester.pumpWidget(
        RepositoryProvider<ProfileRepository>.value(
          value: repository,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
              BlocProvider<EnableLoggingCubit>(
                create: (_) => EnableLoggingCubit(),
              ),
              BlocProvider<OnboardingCubit>(create: (_) => OnboardingCubit()),
              BlocProvider<FavoriteBloc>(
                create: (_) => _FixedFavoriteBloc(
                  const FavoritesLoaded([FavoriteProfile(uuid: uuid)]),
                ),
              ),
              BlocProvider<ProfileListBloc>.value(value: listBloc),
              BlocProvider<ProfileCacheCubit>.value(value: cache),
              BlocProvider<ProfileFolderBloc>(
                create: (_) => ProfileFolderBloc(FakeProfileFolderRepository()),
              ),
              BlocProvider<ProfilesRunningCubit>(
                create: (_) => ProfilesRunningCubit(),
              ),
            ],
            child: MaterialApp(
              navigatorKey: App.navState,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      listBloc.add(const ProfileListUpdateEvent([uuid]));
      await settle(tester);

      final first = trayCubit.reload();
      await settle(tester);
      verify(repository.getProfile(uuid)).called(1);

      final second = trayCubit.reload(
        profileState: ProfileLoaded(
          uuid,
          profile: profile.copyWith(displayName: 'New name'),
        ),
      );
      await settle(tester);
      await second;
      expect(
        menus.last.any((label) => label.contains('New name')),
        isTrue,
        reason: 'the later reload must have set its menu',
      );

      firstName.complete(profile);
      await settle(tester);
      await first;

      expect(
        menus.last.any((label) => label.contains('New name')),
        isTrue,
        reason: 'a reload overtaken by a later one must not replace its menu',
      );
    });
  });
}
