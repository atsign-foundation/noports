import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/srvd.dart';
import 'package:socket_connector/socket_connector.dart';
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

/// Lets a startup get as far as the relay: it holds no keys to sign with, and
/// finds its signing key not yet published.
class _StartableAtClient extends _FailingAtClient {
  @override
  String? get enrollmentId => null;

  @override
  AtKeysIo? get atKeysIo => null;

  @override
  get atChops => null;

  @override
  bool get isStopped => false;

  @override
  Future<AtValue> get(
    AtKey key, {
    bool isDedicated = false,
    GetRequestOptions? getRequestOptions,
  }) async => throw AtKeyNotFoundException('$key does not exist');

  @override
  Future<bool> put(
    AtKey key,
    dynamic value, {
    bool isDedicated = false,
    PutRequestOptions? putRequestOptions,
  }) async => true;
}

/// Delivers notifications synchronously, so a test acts at a known point
/// after a listener has run, and accepts every notification sent.
class _DeliveringNotificationService extends _FakeNotificationService {
  final Completer<void> relayRequested = Completer();

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) => controllers
      .putIfAbsent(regex!, () => StreamController.broadcast(sync: true))
      .stream;

  @override
  Future<NotificationResult> notify(
    NotificationParams notificationParams, {
    bool waitForFinalDeliveryStatus = true,
    bool checkForFinalDeliveryStatus = true,
    bool encryptValue = true,
    Function(NotificationResult)? onSuccess,
    Function(NotificationResult)? onError,
    Function(NotificationResult)? onSentToSecondary,
  }) async {
    if (notificationParams.atKey.key.contains('request_ports') &&
        !relayRequested.isCompleted) {
      relayRequested.complete();
    }
    return NotificationResult()
      ..notificationID = 'n'
      ..notificationStatusEnum = NotificationStatusEnum.delivered;
  }
}

/// Subscriptions to the daemon session regex fail to cancel.
class _UncancellableDaemonNotificationService extends _FakeNotificationService {
  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) => regex!.endsWith('@device\$')
      ? _uncancellable(controllers, regex)
      : super.subscribe(regex: regex, shouldDecrypt: shouldDecrypt);
}

/// A [_DeliveringNotificationService] whose subscriptions to the daemon
/// session regex fail to cancel.
class _UncancellableDaemonDeliveringService
    extends _DeliveringNotificationService {
  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) => regex!.endsWith('@device\$')
      ? _uncancellable(controllers, regex)
      : super.subscribe(regex: regex, shouldDecrypt: shouldDecrypt);
}

/// A stream for [regex], recorded in [controllers], whose cancel fails.
Stream<AtNotification> _uncancellable(
  Map<String, StreamController<AtNotification>> controllers,
  String regex,
) {
  final controller = StreamController<AtNotification>(
    onCancel: () => Future<void>.error(StateError('cancel failed')),
  );
  controllers[regex] = controller;
  return controller.stream;
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

/// Plain relay traffic, so the client connects to a bare local socket.
NptParams _relayParams() => NptParams(
  clientAtSign: '@alice',
  sshnpdAtSign: '@device',
  srvdAtSign: '@rv_test',
  remoteHost: 'localhost',
  remotePort: 3389,
  device: 'test_device',
  inline: true,
  authenticateClientToRvd: false,
  localHost: '127.0.0.1',
  // Longer than the test, so the connector's own grace period can't close it
  timeout: Duration(minutes: 5),
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

  group('Given a runInline whose relay has answered and whose relay '
      'connection is still being made', () {
    test('when close completes and done resolves, then runInline leaves no '
        'SocketConnector open', () async {
      final relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final relaySockets = <Socket>[];
      final controlSocketClosed = Completer<void>();
      relay.listen((socket) {
        relaySockets.add(socket);
        socket.listen(
          (_) {},
          onDone: () {
            if (!controlSocketClosed.isCompleted) {
              controlSocketClosed.complete();
            }
          },
          onError: (_) {},
        );
      });
      addTearDown(() async {
        for (final s in relaySockets) {
          s.destroy();
        }
        await relay.close();
      });

      final notifications = _DeliveringNotificationService();
      final npt = Npt.create(
        atClient: _StartableAtClient()..fakeNotificationService = notifications,
        params: _relayParams(),
      );

      var runInlineSettled = false;
      SocketConnector? connector;
      Object? startupError;
      Future<void> runStartup() async {
        try {
          connector = await npt.runInline(localRvPort: 0);
        } catch (e) {
          startupError = e;
        } finally {
          runInlineSettled = true;
        }
      }

      final started = runStartup();
      addTearDown(() => connector?.close());

      await notifications.relayRequested.future.timeout(Duration(seconds: 5));
      notifications.controllers['${npt.sessionId}.${Srvd.namespace}@']!.add(
        AtNotification(
          'relay-ack',
          '@alice:${npt.sessionId}.${Srvd.namespace}@rv_test',
          '@rv_test',
          '@alice',
          DateTime.now().millisecondsSinceEpoch,
          'key',
          false,
          value: jsonEncode({
            'address': '127.0.0.1',
            'portA': relay.port,
            'portB': relay.port,
            'rvdNonce': 'nonce',
            'supportsEventLogging': false,
          }),
        ),
      );

      await npt.close();
      await npt.done.timeout(Duration(seconds: 5));
      expect(
        runInlineSettled,
        isFalse,
        reason: 'the test must close while the startup is still in flight',
      );

      await started.timeout(Duration(seconds: 10));
      expect(
        connector?.closed ?? true,
        isTrue,
        reason:
            'close had completed and done had resolved, yet the startup went '
            'on to open this connector (startup error: $startupError)',
      );
      expect(
        await controlSocketClosed.future
            .then((_) => true)
            .timeout(Duration(seconds: 2), onTimeout: () => false),
        isTrue,
        reason:
            'the startup\'s connection to the relay must not outlive close, '
            'whether runInline returned or threw (startup error: '
            '$startupError)',
      );
    });
  });

  group(
    'Given a session whose daemon channel subscription fails to cancel',
    () {
      test('when close runs, then the relay channel subscription is still '
          'cancelled', () async {
        final notifications = _UncancellableDaemonNotificationService();
        final npt = Npt.create(
          atClient: _FailingAtClient()..fakeNotificationService = notifications,
          params: _params(),
        );

        // Fails asking the relay for a session, once all three listeners are up
        await expectLater(npt.runInline(), throwsA(isA<Object>()));

        final relayRegex = '${npt.sessionId}.${Srvd.namespace}@';
        expect(
          notifications.controllers.keys,
          containsAll([
            relayRegex,
            '${npt.sessionId}.${npt.namespace}@device\$',
          ]),
          reason: 'the test must reach both channels\' subscriptions',
        );
        expect(
          notifications.controllers[relayRegex]!.hasListener,
          isFalse,
          reason:
              'a failure cancelling the daemon channel must not stop the relay '
              'channel being cancelled',
        );
      });

      test(
        'when close is called, then close completes and done resolves',
        () async {
          final notifications = _UncancellableDaemonDeliveringService();
          final npt = Npt.create(
            atClient: _StartableAtClient()
              ..fakeNotificationService = notifications,
            params: _params(),
          );
          unawaited(() async {
            try {
              await npt.runInline();
            } catch (_) {}
          }());

          await notifications.relayRequested.future.timeout(
            Duration(seconds: 5),
          );
          expect(
            notifications.controllers.keys,
            contains('${npt.sessionId}.${npt.namespace}@device\$'),
            reason: 'the test must reach the daemon channel\'s subscription',
          );

          await expectLater(
            npt.close(),
            completes,
            reason: 'a teardown step that fails must not make close fail',
          );
          await expectLater(npt.done.timeout(Duration(seconds: 5)), completes);
        },
      );
    },
  );

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
