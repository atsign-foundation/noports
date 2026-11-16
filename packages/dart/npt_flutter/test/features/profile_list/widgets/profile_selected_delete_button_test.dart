import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
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
import 'package:npt_flutter/util/language.dart';

import '../../favorite/bloc/favorite_bloc_test.mocks.dart';
import '../../profile/bloc/profile_bloc_test.dart'
    show FakeAtClient, FakeNpt, FakeSettingsBloc;
import '../../profile/bloc/profile_bloc_test.mocks.dart';
import '../../profile_folder/bloc/profile_folder_bloc_test.dart'
    show FakeProfileFolderRepository;

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

  group('Given a keep-alive profile whose daemon is away, waiting to retry, '
      'selected in the profile list', () {
    testWidgets('when the selected profiles are deleted, then that profile is '
        'not deleted', (tester) async {
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
        retryDelay: const Duration(minutes: 10),
        maxRetryDelay: const Duration(minutes: 10),
        createNpt: ({required atClient, required params}) {
          final npt = FakeNpt(
            startupError: TimeoutException('feature check timed out'),
          );
          attempts.add(npt);
          return npt;
        },
      );
      final runningCubit = ProfilesRunningCubit();
      final listBloc = ProfileListBloc(repository);
      final selectedCubit = ProfilesSelectedCubit();
      final favoriteBloc = FavoriteBloc(MockFavoriteRepository());
      final cache = ProfileCacheCubit(repository, createBloc: (_, _) => bloc);
      addTearDown(runningCubit.close);
      addTearDown(listBloc.close);
      addTearDown(selectedCubit.close);
      addTearDown(favoriteBloc.close);
      addTearDown(cache.close);

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
              BlocProvider<ProfilesSelectedCubit>.value(value: selectedCubit),
              BlocProvider<FavoriteBloc>.value(value: favoriteBloc),
              BlocProvider<ProfileCacheCubit>.value(value: cache),
              BlocProvider<ProfileFolderBloc>(
                create: (_) => ProfileFolderBloc(FakeProfileFolderRepository()),
              ),
              BlocProvider<ProfileStartQueueCubit>(
                create: (_) => ProfileStartQueueCubit(cache),
              ),
            ],
            child: MaterialApp(
              navigatorKey: App.navState,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: ProfileSelectedDeleteButton()),
            ),
          ),
        );

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
          () => attempts.length == 1 && attempts.single.closeCalled,
          reason: 'the first attempt must have failed',
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          bloc.state,
          isA<ProfileStarting>(),
          reason: 'the loop must be parked in its backoff, a retry pending',
        );

        selectedCubit.select(uuid);
        await pumpUntil(
          tester,
          () => find.text('Delete').evaluate().isNotEmpty,
          reason: 'a selection must show the delete button',
        );
        await tester.tap(find.text('Delete'));
        await pumpUntil(
          tester,
          () => find.widgetWithText(TextButton, 'Delete').evaluate().isNotEmpty,
          reason: 'the delete button must ask for confirmation',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump();
        await tester.pump();

        expect(
          (listBloc.state as ProfileListLoaded).profiles,
          contains(uuid),
          reason:
              'a profile whose keep-alive will retry is still running, and '
              'running profiles are left out of a bulk delete',
        );
        verifyNever(repository.deleteProfile(uuid));
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

  group('Given a profile selected for bulk delete', () {
    testWidgets('when it starts running before the delete is confirmed, then '
        'it is not deleted', (tester) async {
      final repository = MockProfileRepository();
      when(
        repository.getProfile(uuid, useCache: true),
      ).thenAnswer((_) async => profile);
      when(repository.deleteProfile(any)).thenAnswer((_) async => true);
      final bloc = ProfileBloc(
        repository,
        uuid,
        getAtClient: FakeAtClient.new,
        createNpt: ({required atClient, required params}) =>
            // NOTE: longer than the test, or the connector's own grace period
            // ends the session
            FakeNpt(connectorTimeout: const Duration(minutes: 10)),
      );
      final runningCubit = ProfilesRunningCubit();
      final listBloc = ProfileListBloc(repository);
      final selectedCubit = ProfilesSelectedCubit();
      final favoriteBloc = FavoriteBloc(MockFavoriteRepository());
      final cache = ProfileCacheCubit(repository, createBloc: (_, _) => bloc);
      addTearDown(runningCubit.close);
      addTearDown(listBloc.close);
      addTearDown(selectedCubit.close);
      addTearDown(favoriteBloc.close);
      addTearDown(cache.close);

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
              BlocProvider<ProfilesSelectedCubit>.value(value: selectedCubit),
              BlocProvider<FavoriteBloc>.value(value: favoriteBloc),
              BlocProvider<ProfileCacheCubit>.value(value: cache),
              BlocProvider<ProfileFolderBloc>(
                create: (_) => ProfileFolderBloc(FakeProfileFolderRepository()),
              ),
              BlocProvider<ProfileStartQueueCubit>(
                create: (_) => ProfileStartQueueCubit(cache),
              ),
            ],
            child: MaterialApp(
              navigatorKey: App.navState,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: ProfileSelectedDeleteButton()),
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

        selectedCubit.select(uuid);
        await pumpUntil(
          tester,
          () => find.text('Delete').evaluate().isNotEmpty,
          reason: 'a selection must show the delete button',
        );
        await tester.tap(find.text('Delete'));
        await pumpUntil(
          tester,
          () => find.widgetWithText(TextButton, 'Delete').evaluate().isNotEmpty,
          reason: 'the delete button must ask for confirmation',
        );

        bloc.add(const ProfileStartEvent());
        await pumpUntil(
          tester,
          () =>
              bloc.state is ProfileStarted &&
              runningCubit.state.socketConnectors[uuid] != null,
          reason: 'the profile must be running before the delete is confirmed',
        );

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump();
        await tester.pump();

        expect(
          (listBloc.state as ProfileListLoaded).profiles,
          contains(uuid),
          reason:
              'running profiles are left out of a bulk delete, as the '
              'confirmation says, including one that started while it was '
              'open',
        );
        verifyNever(repository.deleteProfile(uuid));
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
