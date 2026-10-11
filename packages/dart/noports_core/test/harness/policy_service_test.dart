import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/events.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'noports_harness.dart';

/// Rules naming [daemons], answering every check it is asked with a grant,
/// and recording each one.
class _Rules implements NPARequestHandler {
  _Rules(this.daemons);

  final Set<Atsign> daemons;
  final List<NPAAuthCheckRequest> checked = [];

  @override
  bool hasRulesFor(Atsign daemonAtsign) => daemons.contains(daemonAtsign);

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest request) async {
    checked.add(request);
    return NPAAuthCheckResponse(
      authorized: true,
      message: 'allowed',
      permitOpen: ['localhost:22'],
    );
  }
}

void main() {
  group(
      'Given a policy service @policy whose rules name daemon @daemon and not'
      ' @other', () {
    const policy = '@policy';
    const daemon = '@daemon';
    const other = '@other';
    const events = '@events';

    late NoPortsHarness harness;
    late _Rules rules;
    late AtClient policyClient;
    final rpcs = <String, AtRpcClient>{};

    setUp(() async {
      harness = NoPortsHarness.create(atSigns: {policy, daemon, other, events});
      rules = _Rules({daemon.toAtsign()});
      rpcs.clear();

      final listener = AtEventListenerService(
        atClient:
            await harness.openClient(events, namespace: DefaultArgs.namespace),
      );
      await listener.shareEventLoggingConfigWithAtsigns(
        config: await listener.getOrCreateConfig(
          namespace: DefaultArgs.eventLoggingNamespace,
          ttln: 60 * 60 * 1000,
        ),
        atSigns: [policy.toAtsign()],
        namespace: DefaultArgs.eventLoggingNamespace,
      );

      policyClient =
          await harness.openClient(policy, namespace: DefaultArgs.namespace);
      await NPAImpl(
        atClient: policyClient,
        homeDirectory: harness.home.path,
        handler: rules,
        eventLoggingAtsign: events.toAtsign(),
      ).run();
    });

    /// [from]'s auth-check client for [policy], opened once per test.
    Future<AtRpcClient> rpcFor(String from) async =>
        rpcs[from] ??= AtRpcClient(
          serverAtsign: policy,
          atClient:
              await harness.openClient(from, namespace: DefaultArgs.namespace),
          baseNameSpace: DefaultArgs.namespace,
          domainNameSpace: 'auth_checks',
        );

    /// [from] asks [policy] whether `@alice` may use [about]'s device, and
    /// returns the answer, or null when none comes within 2 s.
    Future<Map<String, dynamic>?> ask(String from, {required String about}) async {
      final rpc = await rpcFor(from);
      try {
        return await rpc.call(NPAAuthCheckRequest(
          daemonAtsign: about,
          daemonDeviceName: 'device',
          daemonDeviceGroupName: 'default',
          clientAtsign: '@alice',
        ).toJson()).timeout(const Duration(seconds: 2));
      } on TimeoutException {
        return null;
      }
    }

    /// How many notifications [policy] has sent [to].
    int repliesTo(String to) =>
        harness.server[to].received.where((n) => n.from == policy).length;

    /// [from] sends [policy] a device heartbeat, as a daemon does.
    Future<void> heartbeatFrom(String from) async {
      final atClient =
          await harness.openClient(from, namespace: DefaultArgs.namespace);
      await atClient.notificationService.notify(
        NotificationParams.forUpdate(
          AtKey.fromString(
            '$policy:device.devices.policy.${DefaultArgs.namespace}$from',
          ),
          value: '{"devicename":"device"}',
        ),
        waitForFinalDeliveryStatus: false,
        checkForFinalDeliveryStatus: false,
      );
      await atClient.stop();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    /// The policy log entries [policy] writes while [act] runs, as the
    /// admin API decrypts them, waiting up to 2 s for the first.
    Future<List<Map<String, dynamic>>> policyLogDuring(
        Future<void> Function() act) async {
      final entries = <Map<String, dynamic>>[];
      final subscription = policyClient.notificationService
          .subscribe(regex: r'\.logs\.policy\.sshnp@', shouldDecrypt: true)
          .listen((n) => entries.add(jsonDecode(n.value!)));
      await act();
      for (var i = 0; i < 20 && entries.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await subscription.cancel();
      return entries;
    }

    /// How many times [policy] has shared its event-logging config with [to].
    int configSharesWith(String to) => harness.server[policy].writes
        .where((k) =>
            k == '$to:config.${DefaultArgs.eventLoggingNamespace}$policy')
        .length;

    test(
        'when @daemon asks about one of its clients, then the service answers'
        ' from its rules', () async {
      final answer = await ask(daemon, about: daemon);

      expect(answer?['authorized'], isTrue);
      expect(answer?['permitOpen'], ['localhost:22']);
      expect(rules.checked, hasLength(1));
    });

    test(
        "when @other asks about itself, then the service sends no reply and"
        " doesn't consult its rules", () async {
      expect(await ask(other, about: other), isNull);

      expect(repliesTo(other), 0);
      expect(rules.checked, isEmpty);
    });

    test('when @other asks about @daemon, then the service sends no reply',
        () async {
      expect(await ask(other, about: daemon), isNull);

      expect(repliesTo(other), 0);
      expect(rules.checked, isEmpty);
    });

    test(
        'when @daemon asks about @daemon2, then the service replies'
        ' authorized: false with no permitOpen, without consulting its rules,'
        ' and the policy log gets one entry naming @daemon, its request and'
        ' the refusal', () async {
      late Map<String, dynamic>? answer;
      final log = await policyLogDuring(
          () async => answer = await ask(daemon, about: '@daemon2'));

      expect(answer?['authorized'], isFalse);
      expect(answer?['permitOpen'], isEmpty);
      expect(rules.checked, isEmpty);
      expect(log, hasLength(1),
          reason: 'the refusal is logged like any answer');
      expect(log.single['daemon'], daemon);
      final payload = log.single['payload'];
      expect(payload['request']['payload']['daemonAtsign'], '@daemon2');
      expect(payload['response']['payload']['authorized'], isFalse);
      expect(payload['response']['payload']['message'],
          'A daemon may ask only about itself');
    });

    test(
        "when rules naming @other are added, then @other's next request is"
        ' answered', () async {
      expect(await ask(other, about: other), isNull);

      rules.daemons.add(other.toAtsign());

      expect((await ask(other, about: other))?['authorized'], isTrue);
    });

    test(
        "when the rules naming @daemon are removed, then @daemon's next"
        ' request gets no reply', () async {
      expect((await ask(daemon, about: daemon))?['authorized'], isTrue);
      final repliesBefore = repliesTo(daemon);

      rules.daemons.remove(daemon.toAtsign());

      expect(await ask(daemon, about: daemon), isNull);
      expect(repliesTo(daemon), repliesBefore);
    });

    test(
        'when @daemon sends a heartbeat, then the service shares its'
        ' event-logging config with @daemon, once', () async {
      await heartbeatFrom(daemon);
      await heartbeatFrom(daemon);

      expect(configSharesWith(daemon), 1);
    });

    test(
        "when @other sends a heartbeat, then the service shares nothing with"
        " it, and doesn't add it to the set it has shared with", () async {
      await heartbeatFrom(other);
      expect(configSharesWith(other), 0);

      rules.daemons.add(other.toAtsign());
      await heartbeatFrom(other);

      expect(configSharesWith(other), 1,
          reason: 'an earlier heartbeat without rules left nothing behind');
    });
  });
}
