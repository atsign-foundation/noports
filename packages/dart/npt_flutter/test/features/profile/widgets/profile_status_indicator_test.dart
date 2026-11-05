import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../bloc/profile_bloc_test.mocks.dart';

const _uuid = 'test-uuid';

final _profile = Profile(
  _uuid,
  displayName: 'Test',
  relayAtsign: '@relay'.toAtsign(),
  sshnpdAtsign: '@device'.toAtsign(),
  deviceName: 'device',
  localPort: 3389,
  remoteHost: 'localhost',
  remotePort: 3389,
);

/// A [ProfileBloc] pinned to one state, recording what it is sent.
class _RecordingProfileBloc extends ProfileBloc {
  _RecordingProfileBloc(this.pinned) : super(MockProfileRepository(), _uuid);

  final ProfileState pinned;
  final List<ProfileEvent> sent = [];

  @override
  ProfileState get state => pinned;

  @override
  Stream<ProfileState> get stream => const Stream.empty();

  @override
  void add(ProfileEvent event) => sent.add(event);
}

void main() {
  Future<_RecordingProfileBloc> pumpIndicator(
    WidgetTester tester,
    ProfileState state,
  ) async {
    final bloc = _RecordingProfileBloc(state);
    addTearDown(bloc.close);
    final cache = ProfileCacheCubit(MockProfileRepository());
    addTearDown(cache.close);
    final queue = ProfileStartQueueCubit(cache);
    addTearDown(queue.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileStartQueueCubit>.value(value: queue),
              BlocProvider<ProfileBloc>.value(value: bloc),
            ],
            child: const ProfileStatusIndicator(),
          ),
        ),
      ),
    );
    return bloc;
  }

  group('Given a profile that is starting', () {
    testWidgets('when its indicator is tapped, then the profile is stopped', (
      tester,
    ) async {
      final bloc = await pumpIndicator(
        tester,
        ProfileStarting(_uuid, profile: _profile, status: 'retrying'),
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'a starting profile still shows that it is connecting',
      );
      await tester.tap(find.byType(InkWell));

      expect(
        bloc.sent,
        [const ProfileStopEvent()],
        reason:
            'a connection that keeps failing must be abandonable from '
            'the main window, not only the tray',
      );
    });
  });

  group('Given a profile that is stopping', () {
    testWidgets('then its indicator offers nothing to tap', (tester) async {
      await pumpIndicator(tester, ProfileStopping(_uuid, profile: _profile));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
