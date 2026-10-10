import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/events/event_models.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// A subscription the daemon made, and the notifications it has delivered.
class _Subscription {
  _Subscription(String? regex) : regex = RegExp(regex ?? '');

  final RegExp regex;
  final List<AtNotification> delivered = [];
}

void main() {
  group('Given a daemon whose policy atSign is @policy', () {
    const policy = '@policy';
    const device = 'testdevice';

    late StreamController<AtNotification> notifications;
    late List<_Subscription> subscriptions;
    late List<Object> uncaught;

    setUp(() {
      notifications = StreamController<AtNotification>.broadcast();
      subscriptions = [];
      uncaught = [];
    });

    tearDown(() => notifications.close());

    MockAtClient atClient() {
      final atClient = MockAtClient();
      final notificationService = MockNotificationService();
      when(() => atClient.notificationService).thenReturn(notificationService);
      when(() => atClient.getCurrentAtSign()).thenReturn('@device');
      // Delivers what each subscription's regex matches, as at_client does.
      when(
        () => notificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((invocation) {
        final subscription =
            _Subscription(invocation.namedArguments[#regex] as String?);
        subscriptions.add(subscription);
        return notifications.stream
            .where((n) => subscription.regex.hasMatch(n.key))
            .map((n) {
          subscription.delivered.add(n);
          return n;
        });
      });
      return atClient;
    }

    SshnpdImpl daemon() => SshnpdImpl(
          atClient: atClient(),
          username: 'testuser',
          homeDirectory: Directory.systemTemp.path,
          device: device,
          managerAtsigns: ['@manager'],
          policyManagerAtsign: policy.toAtsign(),
          sshClient: SupportedSshClient.openssh,
          makeDeviceInfoVisible: false,
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
        );

    /// Starts [d]'s policy subscription, recording any error that escapes its
    /// listener, and returns that subscription.
    Future<_Subscription> subscribe(SshnpdImpl d) async {
      final before = subscriptions.length;
      await runZonedGuarded(
        d.subscribeToPolicyUpdates,
        (e, _) => uncaught.add(e),
      );
      expect(
        subscriptions,
        hasLength(before + 1),
        reason: 'the daemon makes one policy subscription',
      );
      return subscriptions.last;
    }

    Future<void> send(AtNotification n) async {
      notifications.add(n);
      await pumpEventQueue();
    }

    AtNotification config(String value, {String from = policy}) =>
        AtNotification(
          'config-id',
          '@device:config.$device.devices.policy.${DefaultArgs.namespace}$from',
          from,
          '@device',
          1,
          'key',
          true,
          value: value,
        );

    String configFor(String eventsAtSign) => jsonEncode({
          'eventLoggingConfig': {
            'atSign': eventsAtSign,
            'topic': 'abc.events.logging.sshnp',
            'ttln': 60000,
          },
        });

    final existing = AtEventConfig(
      atSign: '@events'.toAtsign(),
      topic: 'existing.events.logging.sshnp',
      ttln: 60000,
    );

    test(
        'when @policy sends a config, then the daemon takes its event-logging'
        ' config', () async {
      final d = daemon()..elc = existing;
      final subscription = await subscribe(d);

      await send(config(configFor('@events2')));

      expect(subscription.delivered, hasLength(1));
      expect(d.elc?.atSign, '@events2');
      expect(uncaught, isEmpty);
    });

    test(
        "when @policy sends a config that isn't JSON, then the daemon keeps its"
        ' event-logging config and keeps running', () async {
      final d = daemon()..elc = existing;
      final subscription = await subscribe(d);

      await send(config('not json'));

      expect(subscription.delivered, hasLength(1));
      expect(uncaught, isEmpty, reason: 'no error escapes the listener');
      expect(d.elc, same(existing));
    });
  });
}
