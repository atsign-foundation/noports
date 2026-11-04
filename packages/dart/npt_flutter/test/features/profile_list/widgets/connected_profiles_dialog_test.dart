import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/connected_profiles_dialog.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:socket_connector/socket_connector.dart';

import '../../profile/bloc/profile_bloc_test.dart'
    show FakeAtClient, FakeNpt, FakeSettingsBloc;
import '../../profile/bloc/profile_bloc_test.mocks.dart';

/// Ends its session when its connector closes, as a real [Npt] does.
class _ConnectorBoundNpt extends FakeNpt {
  // NOTE: longer than the test, or the connector's own grace period ends the
  // session
  _ConnectorBoundNpt() : super(connectorTimeout: const Duration(minutes: 10));

  @override
  Future<SocketConnector> runInline({int? localRvPort}) async {
    final sc = await super.runInline(localRvPort: localRvPort);
    unawaited(sc.done.then((_) => close()));
    return sc;
  }
}

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
    testWidgets('when Stop all is confirmed in the connected profiles dialog, '
        'then no further session attempt is made', (tester) async {
      final repository = MockProfileRepository();
      when(
        repository.getProfile(uuid, useCache: true),
      ).thenAnswer((_) async => profile);
      final attempts = <FakeNpt>[];
      final bloc = ProfileBloc(
        repository,
        uuid,
        getAtClient: FakeAtClient.new,
        retryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 40),
        createNpt: ({required atClient, required params}) {
          final npt = _ConnectorBoundNpt();
          attempts.add(npt);
          return npt;
        },
      );
      final runningCubit = ProfilesRunningCubit();
      final listBloc = ProfileListBloc(repository);
      final cache = ProfileCacheCubit(repository, createBloc: (_, _) => bloc);
      addTearDown(listBloc.close);
      addTearDown(cache.close);
      addTearDown(runningCubit.close);

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
            ],
            child: MaterialApp(
              navigatorKey: App.navState,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const ConnectedProfilesDialog(),
                  ),
                  child: const Text('open'),
                ),
              ),
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
          () => bloc.state is ProfileStarted,
          reason: 'the session must start',
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump();
        expect(
          find.text(profile.displayName),
          findsOneWidget,
          reason: 'the dialog must list the running profile',
        );

        await tester.tap(find.text('Confirm'));
        await pumpFor(tester, const Duration(milliseconds: 200));

        expect(
          attempts.first.connector!.closed,
          isTrue,
          reason: 'confirming must have stopped the running session',
        );
        expect(
          attempts,
          hasLength(1),
          reason:
              'Stop all must end the profile\'s keep-alive, not only close its '
              'current connection',
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

  group('Given a profile listed as running whose bloc is already closed', () {
    testWidgets('when Stop all is confirmed in the connected profiles dialog, '
        'then the dialog closes and the profile is no longer listed', (
      tester,
    ) async {
      final repository = MockProfileRepository();
      final runningCubit = ProfilesRunningCubit();
      final listBloc = ProfileListBloc(repository);
      final cache = ProfileCacheCubit(repository);
      addTearDown(listBloc.close);
      addTearDown(cache.close);
      addTearDown(runningCubit.close);
      final connector = SocketConnector(timeout: const Duration(minutes: 10));
      addTearDown(connector.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
            BlocProvider<EnableLoggingCubit>(
              create: (_) => EnableLoggingCubit(),
            ),
            BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
            BlocProvider<ProfileListBloc>.value(value: listBloc),
            BlocProvider<ProfileCacheCubit>.value(value: cache),
          ],
          child: MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const ConnectedProfilesDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      final bloc = cache.getProfileBloc(uuid);
      unawaited(bloc.close());
      runningCubit.cache(uuid, connector);
      listBloc.add(const ProfileListUpdateEvent([uuid]));
      await pumpUntil(
        tester,
        () => bloc.isClosed && listBloc.state is ProfileListLoaded,
        reason: 'the bloc must be closed and the list loaded',
      );

      await tester.tap(find.text('open'));
      await pumpUntil(
        tester,
        () => find.text('Confirm').evaluate().isNotEmpty,
        reason: 'the dialog must offer to stop the listed profile',
      );
      await tester.tap(find.text('Confirm'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(
        find.byType(ConnectedProfilesDialog),
        findsNothing,
        reason: 'Confirm must close the dialog',
      );
      expect(
        runningCubit.state.socketConnectors.keys,
        isNot(contains(uuid)),
        reason:
            'a listed profile with no bloc left to stop it must be unlisted',
      );
      expect(connector.closed, isTrue);
    });
  });
}
