import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/at_ssh_key_util/local_ssh_key_util.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AtKey());
    registerFallbackValue(NotificationParams.forUpdate(AtKey()..key = 'k'));
  });

  late MockAtClient atClient;
  late MockNotificationService notificationService;
  late List<(String?, StreamController<AtNotification>)> subscriptions;
  late StreamController<NotificationListenerState> listenerStates;

  setUp(() {
    atClient = MockAtClient();
    notificationService = MockNotificationService();
    subscriptions = [];
    listenerStates = StreamController<NotificationListenerState>.broadcast();
    when(() => atClient.notificationService).thenReturn(notificationService);
    when(() => atClient.getCurrentAtSign()).thenReturn('@device');
    when(
      () => notificationService.subscribe(
        regex: any(named: 'regex'),
        shouldDecrypt: any(named: 'shouldDecrypt'),
      ),
    ).thenAnswer((invocation) {
      final controller = StreamController<AtNotification>.broadcast();
      subscriptions.add((invocation.namedArguments[#regex], controller));
      return controller.stream;
    });
    when(
      () => notificationService.currentListenerStateStream,
    ).thenAnswer((_) => listenerStates.stream);
    when(
      () => notificationService.notify(
        any(),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        onSuccess: any(named: 'onSuccess'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => NotificationResult());
    when(
      () => atClient.put(
        any(),
        any(),
        putRequestOptions: any(named: 'putRequestOptions'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => atClient.get(any(), getRequestOptions: any(named: 'getRequestOptions')),
    ).thenThrow(AtKeyNotFoundException('no event logging config'));
  });

  SshnpdImpl daemon({bool makeDeviceInfoVisible = false, String? policy}) =>
      SshnpdImpl(
        atClient: atClient,
        username: 'testuser',
        homeDirectory: Directory.systemTemp.path,
        device: 'testdevice',
        managerAtsigns: ['@manager'],
        policyManagerAtsign: policy?.toAtsign(),
        sshClient: SupportedSshClient.openssh,
        makeDeviceInfoVisible: makeDeviceInfoVisible,
        addSshPublicKeys: false,
        localSshdPort: 22,
        sshPublicKeyPermissions: '',
        ephemeralPermissions: '',
        sshAlgorithm: SupportedSshAlgorithm.rsa,
        deviceGroup: 'default',
        version: '1.0.0',
        permitOpen: ['localhost:22'],
        strict: false,
        clientKeyCheckInterval:
            const Duration(seconds: DefaultSshnpdArgs.clientKeyCheckSecs),
        requireEnrollmentSignature: false,
      )..initialized = true;

  /// Runs [daemon] in a zone that records its periodic timers and fires its
  /// one-shot timers at once, and returns the periodic timers.
  Future<List<Timer>> runRecordingTimers(SshnpdImpl daemon) async {
    final periodic = <Timer>[];
    await runZoned(
      daemon.run,
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, period, f) {
          final timer = parent.createPeriodicTimer(zone, period, f);
          periodic.add(timer);
          return timer;
        },
        createTimer: (self, parent, zone, duration, f) =>
            parent.createTimer(zone, Duration.zero, f),
      ),
    );
    return periodic;
  }

  /// The regexes whose subscriptions still have a listener.
  List<String?> listening() =>
      [for (final (regex, c) in subscriptions) if (c.hasListener) regex];

  // NOTE the auth-check AtRpc keeps no handle on its subscription and has
  // no stop, so it lives until the AtClient's notification service stops.
  for (final (label, deviceInfo, policy, timerCount, survivors) in [
    ('minimal', false, null, 3, 0),
    ('device info and a policy manager', true, '@policy', 4, 1),
  ]) {
    test('stop() ends every timer and subscription run() started ($label)',
        () async {
      final d = daemon(makeDeviceInfoVisible: deviceInfo, policy: policy);
      addTearDown(d.stop);
      final timers = await runRecordingTimers(d);

      expect(timers, hasLength(timerCount));
      expect(timers.every((t) => t.isActive), isTrue);
      expect(listening(), hasLength(subscriptions.length));
      expect(listenerStates.hasListener, isTrue);

      await d.stop();

      expect(timers.where((t) => t.isActive), isEmpty);
      expect(listening(), hasLength(survivors));
      expect(listening(), everyElement(contains('auth_checks')));
      expect(listenerStates.hasListener, isFalse);
    });
  }

  test('stop() during run() leaves nothing running', () async {
    final stalled = Completer<void>();
    final release = Completer<void>();
    when(
      () => notificationService.notify(
        any(),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        onSuccess: any(named: 'onSuccess'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async {
      if (!stalled.isCompleted) stalled.complete();
      await release.future;
      return NotificationResult();
    });
    final d = daemon(makeDeviceInfoVisible: true);
    final running = runRecordingTimers(d);
    await stalled.future;
    expect(subscriptions, isEmpty);

    await d.stop();
    release.complete();
    final timers = await running;

    expect(timers, hasLength(4));
    expect(subscriptions, hasLength(2));
    expect(timers.where((t) => t.isActive), isEmpty);
    expect(listening(), isEmpty);
    expect(listenerStates.hasListener, isFalse);
  });

  group('pending ephemeral keys', () {
    const userKey = 'ssh-ed25519 AAAAexistingUserKey user@laptop';
    late Directory home;
    late File authKeys;
    late LocalSshKeyUtil keyUtil;
    late String sessionId;

    setUp(() async {
      home = Directory.systemTemp.createTempSync('sshnpd_stop_test');
      Directory('${home.path}/.ssh').createSync();
      authKeys = File('${home.path}/.ssh/authorized_keys')
        ..writeAsStringSync('$userKey\n');
      keyUtil = LocalSshKeyUtil(homeDirectory: home.path);
      sessionId = Uuid().v4();
      await keyUtil.authorizePublicKey(
        sshPublicKey: 'ssh-ed25519 AAAAephemeralKey',
        localSshdPort: 22,
        sessionId: sessionId,
      );
    });

    tearDown(() => home.deleteSync(recursive: true));

    /// Waits up to a second for authorized_keys to hold only the user's key.
    Future<List<String>> untilOnlyUserKey() async {
      final deadline = DateTime.now().add(const Duration(seconds: 1));
      while (authKeys.readAsLinesSync().length > 1 &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return authKeys.readAsLinesSync();
    }

    test('stop() removes a key still waiting for its timer', () async {
      final d = daemon()
        ..deauthorizeAfter(const Duration(hours: 1), sessionId, keyUtil);
      expect(authKeys.readAsLinesSync(), hasLength(2));

      await d.stop();

      expect(authKeys.readAsLinesSync(), [userKey]);
    });

    test('a key is removed when its timer fires', () async {
      daemon().deauthorizeAfter(Duration.zero, sessionId, keyUtil);

      expect(await untilOnlyUserKey(), [userKey]);
    });

    test('a key scheduled after stop() is removed at once', () async {
      final d = daemon();
      await d.stop();

      d.deauthorizeAfter(const Duration(hours: 1), sessionId, keyUtil);

      expect(await untilOnlyUserKey(), [userKey]);
    });

    test('stop() waits for a removal already under way', () async {
      final d = daemon()
        ..deauthorizeAfter(Duration.zero, sessionId, keyUtil);
      await Future.delayed(Duration.zero);

      await d.stop();

      expect(authKeys.readAsLinesSync(), [userKey]);
    });

    test('stop() carries on past a removal that fails', () async {
      final gone = Directory.systemTemp.createTempSync('sshnpd_stop_gone');
      final failing = LocalSshKeyUtil(homeDirectory: gone.path);
      gone.deleteSync(recursive: true);
      final d = daemon()
        ..deauthorizeAfter(const Duration(hours: 1), Uuid().v4(), failing)
        ..deauthorizeAfter(const Duration(hours: 1), sessionId, keyUtil);

      await d.stop();

      expect(authKeys.readAsLinesSync(), [userKey]);
    });
  });
}
