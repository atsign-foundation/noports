import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

/// Minimal stand-in - these tests only exercise the startup failure path, so
/// the only calls that must succeed are the ones [NptBase]'s constructor makes.
class _FailingAtClient implements AtClient {
  AtClientPreference _preference = AtClientPreference()
    ..rootDomain = 'root.atsign.org';

  @override
  AtClientPreference? getPreferences() => _preference;

  @override
  void setPreferences(AtClientPreference preference) =>
      _preference = preference;

  @override
  String? getCurrentAtSign() => '@alice';

  /// Null unless a test wants subscriptions to succeed.
  NotificationService? fakeNotificationService;

  @override
  NotificationService get notificationService =>
      fakeNotificationService ??
      noSuchMethod(Invocation.getter(#notificationService));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not available');
}

/// Hands out one broadcast stream per regex, so a test can tell whether
/// anything is still listening to it.
class _FakeNotificationService implements NotificationService {
  final Map<String, StreamController<AtNotification>> controllers = {};

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) => controllers
      .putIfAbsent(regex!, () => StreamController.broadcast())
      .stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not available');
}

NptParams _params() => NptParams(
  clientAtSign: '@alice',
  sshnpdAtSign: '@device',
  srvdAtSign: '@rv_test',
  remoteHost: 'localhost',
  remotePort: 3389,
  device: 'test_device',
  inline: true,
  timeout: Duration(seconds: 1),
);

void main() {
  group('Npt.done completes on startup failure', () {
    /// Regression coverage for
    /// https://github.com/atsign-foundation/noports/issues/2789 - `done` used
    /// to be completed only on the success paths, so a caller which awaited it
    /// after a failed startup (as NoPorts Desktop does) waited forever.
    test('runInline which throws still completes done', () async {
      final npt = Npt.create(atClient: _FailingAtClient(), params: _params());

      await expectLater(npt.runInline(), throwsA(isA<Object>()));

      await expectLater(
        npt.done.timeout(Duration(seconds: 5)),
        completes,
        reason: 'done must not hang once startup has failed',
      );
    });

    test('run which throws still completes done', () async {
      final npt = Npt.create(atClient: _FailingAtClient(), params: _params());

      await expectLater(npt.run(), throwsA(isA<Object>()));

      await expectLater(
        npt.done.timeout(Duration(seconds: 5)),
        completes,
        reason: 'done must not hang once startup has failed',
      );
    });

    test(
      'close is idempotent, so a late close cannot double complete',
      () async {
        final npt = Npt.create(atClient: _FailingAtClient(), params: _params());

        await expectLater(npt.runInline(), throwsA(isA<Object>()));

        // runInline already closed us on its way out; this must be a no-op
        // rather than a "Completer already completed" state error
        await npt.close();
        await npt.close();

        await expectLater(npt.done.timeout(Duration(seconds: 5)), completes);
      },
    );
  });

  group('Npt.close releases the session\'s notification subscriptions', () {
    /// A keep-alive client retries a failing startup indefinitely, so anything
    /// one attempt leaves attached to the AtClient accumulates without bound.
    test(
      'Given a startup that fails once the daemon and relay channels have '
      'subscribed, when runInline throws, then nothing is still listening',
      () async {
        final notifications = _FakeNotificationService();
        final npt = Npt.create(
          atClient: _FailingAtClient()..fakeNotificationService = notifications,
          params: _params(),
        );

        // Fails asking the relay for a session: by then the daemon session
        // listener, the ping listener and the relay ack listener are all up.
        // The ping's own notify fails too, after the relay's - which must not
        // surface as an unhandled error.
        await expectLater(npt.runInline(), throwsA(isA<Object>()));

        expect(
          notifications.controllers.keys,
          unorderedEquals([
            '${npt.sessionId}.${npt.namespace}@device\$',
            'heartbeat.test_device.sshnp',
            '${npt.sessionId}.${Srvd.namespace}@',
          ]),
          reason:
              'the test must reach all three subscriptions to mean anything',
        );
        notifications.controllers.forEach((regex, controller) {
          expect(
            controller.hasListener,
            isFalse,
            reason: '"$regex" is still listened to after the session closed',
          );
        });
      },
    );
  });

  group('Npt startup leaves no error unhandled', () {
    test(
      'Given a daemon feature check that fails while the relay step is still '
      'running, when the relay step throws, then runInline throws that and '
      'nothing goes unhandled',
      () async {
        final unhandled = <Object>[];
        final thrown = Completer<Object?>();
        // The Npt is built inside the zone: a future's error never crosses
        // error zones, so one made outside would escape the check.
        unawaited(
          runZonedGuarded(() async {
            final npt = Npt.create(
              atClient: _FailingAtClient()
                ..fakeNotificationService = _FakeNotificationService(),
              params: _params(),
            );
            try {
              await npt.runInline();
              thrown.complete(null);
            } catch (e) {
              thrown.complete(e);
            }
          }, (e, _) => unhandled.add(e)),
        );

        expect(await thrown.future, isNotNull);
        // let the feature check's own failure land
        await Future.delayed(Duration(milliseconds: 100));
        expect(
          unhandled,
          isEmpty,
          reason:
              'the feature check is awaited only after the relay answers, so '
              'once the relay step throws it is never awaited, and its failure '
              'would be unhandled - which kills the npt binary - unless it is '
              'ignored up front',
        );
      },
    );
  });
}
