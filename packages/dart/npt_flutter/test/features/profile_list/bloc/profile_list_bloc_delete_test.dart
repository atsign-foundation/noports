import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';

import '../../favorite/bloc/favorite_bloc_test.mocks.dart';
import '../../profile/bloc/profile_bloc_test.dart'
    show FakeAtClient, FakeNpt, FakeSettingsBloc;
import '../../profile/bloc/profile_bloc_test.mocks.dart';

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
    keepAlive: true,
  );
  final settings = Settings(
    relayAtsign: '@relay'.toAtsign(),
    overrideRelay: false,
    viewLayout: PreferredViewLayout.minimal,
    darkMode: false,
    language: Language.english,
  );

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    required String reason,
  }) async {
    for (var i = 0; i < 500 && !condition(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue, reason: reason);
  }

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    const step = Duration(milliseconds: 10);
    for (var t = Duration.zero; t < duration; t += step) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(step);
    }
  }

  group('Given a keep-alive profile whose session is running', () {
    testWidgets('when the profile is deleted, then its session is closed and '
        'its bloc is closed', (tester) async {
      final repository = MockProfileRepository();
      when(
        repository.getProfile(uuid, useCache: true),
      ).thenAnswer((_) async => profile);
      when(repository.deleteProfile(any)).thenAnswer((_) async => true);
      final attempts = <FakeNpt>[];
      final bloc = ProfileBloc(
        repository,
        uuid,
        getAtClient: FakeAtClient.new,
        retryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 40),
        createNpt: ({required atClient, required params}) {
          // NOTE: longer than the test, or the connector's own grace period
          // ends the session
          final npt = FakeNpt(connectorTimeout: const Duration(minutes: 10));
          attempts.add(npt);
          return npt;
        },
      );
      final runningCubit = ProfilesRunningCubit();
      final listBloc = ProfileListBloc(repository);
      final cache = ProfileCacheCubit(repository, createBloc: (_, _) => bloc);
      final favoriteBloc = FavoriteBloc(MockFavoriteRepository());
      addTearDown(runningCubit.close);
      addTearDown(listBloc.close);
      addTearDown(cache.close);
      addTearDown(favoriteBloc.close);

      try {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
              BlocProvider<EnableLoggingCubit>(
                create: (_) => EnableLoggingCubit(),
              ),
              BlocProvider<SettingsBloc>.value(
                value: FakeSettingsBloc(SettingsLoaded(settings: settings)),
              ),
              BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
              BlocProvider<ProfileListBloc>.value(value: listBloc),
              BlocProvider<ProfileCacheCubit>.value(value: cache),
              BlocProvider<FavoriteBloc>.value(value: favoriteBloc),
            ],
            child: MaterialApp(
              navigatorKey: App.navState,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SizedBox.shrink(),
            ),
          ),
        );

        expect(cache.getProfileBloc(uuid), same(bloc));
        bloc.add(const ProfileLoadEvent());
        listBloc.add(const ProfileListUpdateEvent([uuid]));
        await pumpUntil(
          tester,
          () =>
              bloc.state is ProfileLoaded &&
              listBloc.state is ProfileListLoaded,
          reason: 'the profile and the list must load',
        );
        bloc.add(const ProfileStartEvent());
        await pumpUntil(
          tester,
          () => bloc.state is ProfileStarted,
          reason: 'the session must start',
        );

        listBloc.add(const ProfileListDeleteEvent(toDelete: [uuid]));
        await pumpFor(tester, const Duration(milliseconds: 100));

        expect(
          (listBloc.state as ProfileListLoaded).profiles,
          isNot(contains(uuid)),
          reason: 'the test must observe the profile after it was deleted',
        );
        expect(
          attempts.single.closeCalled,
          isTrue,
          reason:
              'a deleted profile can no longer be stopped from the UI, so '
              'deleting it must close its session',
        );
        expect(
          bloc.isClosed,
          isTrue,
          reason: 'a deleted profile\'s bloc must be closed',
        );
      } finally {
        var closed = false;
        unawaited(bloc.close().then((_) => closed = true));
        for (var i = 0; i < 500 && !closed; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 10));
        }
      }
    });
  });
}
