import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/events.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/npp.dart'
    show
        Client,
        ClientGroup,
        ClientGroupMember,
        Daemon,
        NppCache,
        NppService,
        Service,
        ServiceACL;
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

/// Records every log line, so a test can check what was logged.
class _CapturingLoggingHandler implements LoggingHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void call(LogRecord record) => records.add(record);
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

  group('Given a policy service @policy with no event-logging atSign', () {
    const policy = '@policy';
    const daemon = '@daemon';

    final logs = _CapturingLoggingHandler();
    late LoggingHandler previousHandler;
    late NoPortsHarness harness;

    setUpAll(() {
      previousHandler = AtSignLogger.defaultLoggingHandler;
      AtSignLogger.defaultLoggingHandler = logs;
    });

    tearDownAll(() => AtSignLogger.defaultLoggingHandler = previousHandler);

    setUp(() async {
      logs.records.clear();
      harness = NoPortsHarness.create(atSigns: {policy, daemon});
      await NPAImpl(
        atClient:
            await harness.openClient(policy, namespace: DefaultArgs.namespace),
        homeDirectory: harness.home.path,
        handler: _Rules({daemon.toAtsign()}),
        eventLoggingAtsign: null,
      ).run();
    });

    test(
        'when @daemon asks about one of its clients, then the service answers,'
        ' and logs nothing at warning or above', () async {
      final rpc = AtRpcClient(
        serverAtsign: policy,
        atClient:
            await harness.openClient(daemon, namespace: DefaultArgs.namespace),
        baseNameSpace: DefaultArgs.namespace,
        domainNameSpace: 'auth_checks',
      );

      final answer = await rpc.call(NPAAuthCheckRequest(
        daemonAtsign: daemon,
        daemonDeviceName: 'device',
        daemonDeviceGroupName: 'default',
        clientAtsign: '@alice',
      ).toJson()).timeout(const Duration(seconds: 2));

      expect(answer['authorized'], isTrue);
      expect(
          logs.records
              .where((r) => r.level >= Level.WARNING)
              .map((r) => r.message),
          isEmpty);
    });
  });

  group(
      'Given an npp policy service @policy whose rules hold a different number'
      ' of each kind', () {
    const policy = '@policy';
    const events = '@events';

    late NoPortsHarness harness;
    late List<Map<String, dynamic>> received;
    final npaLogs = <LogRecord>[];
    Logger? npaLogger;
    StreamSubscription<LogRecord>? npaLogSubscription;
    NppService? startedNpp;

    setUp(() async {
      harness = NoPortsHarness.create(atSigns: {policy, events});
      received = [];
      npaLogs.clear();

      final listener = AtEventListenerService(
        atClient:
            await harness.openClient(events, namespace: DefaultArgs.namespace),
      );
      final elc = await listener.getOrCreateConfig(
        namespace: DefaultArgs.eventLoggingNamespace,
        ttln: 60 * 60 * 1000,
      );
      await listener.shareEventLoggingConfigWithAtsigns(
        config: elc,
        atSigns: [policy.toAtsign()],
        namespace: DefaultArgs.eventLoggingNamespace,
      );
      listener
          .getJsonStream(elc)
          .listen((json) => received.add(jsonDecode(json)));
    });

    tearDown(() async {
      await startedNpp?.stop(reason: 'test ended');
      startedNpp = null;
      await npaLogSubscription?.cancel();
      npaLogger?.level = Level.SHOUT;
    });

    /// Rules holding a different number of each kind, so a count reported
    /// under the wrong name shows up: 2 clients, 3 client groups, 6 client
    /// group members, 1 daemon, 4 services and 5 service ACLs.
    NppCache rulesOfEachKind() {
      final rules = NppCache();
      final clients = [
        Client(name: 'Alice', atSign: '@alice'),
        Client(name: 'Bob', atSign: '@bob'),
      ];
      final groups = [
        ClientGroup(name: 'g1'),
        ClientGroup(name: 'g2'),
        ClientGroup(name: 'g3'),
      ];
      for (final client in clients) {
        rules.putClient(client);
      }
      for (final group in groups) {
        rules.putClientGroup(group);
      }
      for (final client in clients) {
        for (final group in groups) {
          rules.putClientGroupMember(ClientGroupMember(
              clientId: client.id!, clientGroupId: group.id!));
        }
      }
      final daemon = Daemon(atSign: '@daemon');
      rules.putDaemon(daemon);
      final services = [
        for (var i = 1; i <= 4; i++)
          Service(
              daemonId: daemon.id!,
              deviceName: 'device$i',
              deviceGroupName: '__none__'),
      ];
      for (final service in services) {
        rules.putService(service);
      }
      for (var i = 1; i <= 5; i++) {
        rules.putServiceACL(ServiceACL(
            serviceId: services.first.id!,
            clientGroupId: groups.first.id!,
            permitOpen: 'localhost:$i'));
      }
      return rules;
    }

    /// Starts [policy]'s npp service, as npp.dart does after loading its
    /// rules from files, recording everything its NPAImpl logs in [npaLogs],
    /// and returns it.
    Future<NppService> start({required String? eventLoggingAtSign}) async {
      final npp = NppService(
        atClient:
            await harness.openClient(policy, namespace: DefaultArgs.namespace),
        nppCache: rulesOfEachKind(),
        managerAllowList: {policy},
        binariesVersion: '1.2.3',
        persistenceMethod: 'file',
        homeDirectory: harness.home.path,
        eventLoggingAtSign: eventLoggingAtSign,
      )..init();
      startedNpp = npp;
      // NOTE NPAImpl's logger is set to SHOUT, so it is lowered here to see
      // its warnings; every NPAImpl shares it, so tearDown restores it
      npaLogger = npp.npa.logger.logger..level = Level.ALL;
      npaLogSubscription = npaLogger!.onRecord.listen(npaLogs.add);
      await npp.start();
      return npp;
    }

    /// How many events [policy] has sent @events, as @events's atServer
    /// holds them. The shared key notification that @policy's first encrypted
    /// send brings is left out: it isn't an event.
    int eventsSent() => harness.server[events].received
        .where((n) => n.from == policy)
        .where((n) => n.key.contains('.${DefaultArgs.eventLoggingNamespace}@'))
        .length;

    test(
        'when it starts with @events as its event logging Atsign, then @events'
        ' receives one rulesLoaded event from @policy counting its rules',
        () async {
      await start(eventLoggingAtSign: events);
      for (var i = 0; i < 50 && received.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      expect(received, hasLength(1));
      final event = received.single;
      expect(event['event'], 'rulesLoaded');
      expect(event['sender'], policy);
      expect(event['policyAtsign'], policy);
      expect(event['timestamp'], endsWith('Z'));
      expect(event['persistenceMethod'], 'file');
      expect(event['binariesVersion'], '1.2.3');
      expect(event['rules'], {
        'clients': 2,
        'clientGroups': 3,
        'clientGroupMembers': 6,
        'daemons': 1,
        'services': 4,
        'serviceACLs': 5,
      });
    });

    test(
        'when it starts and stops with no event logging Atsign, then it sends'
        ' @events nothing, and its policy service logs nothing at warning or'
        ' above',
        () async {
      final npp = await start(eventLoggingAtSign: null);
      await Future.delayed(const Duration(seconds: 1));
      await npp.stop(reason: 'SIGINT');

      expect(received, isEmpty);
      expect(
          harness.server[events].received.where((n) => n.from == policy),
          isEmpty);
      expect(
          npaLogs
              .where((r) => r.level >= Level.WARNING)
              .map((r) => r.message),
          isEmpty);
      expect(npp.heartbeatRunning, isFalse);
    });

    test(
        'when its policy service flushes its events, then every event it had'
        ' sent has reached @events, and an event sent afterwards is dropped'
        ' with a log line rather than thrown', () async {
      final npp = await start(eventLoggingAtSign: events);
      for (var i = 1; i <= 5; i++) {
        await npp.npa.sendEvent({'event': 'test$i'});
      }

      await npp.npa.flushEvents();

      expect(eventsSent(), 6,
          reason: 'rulesLoaded and the five test events, with no waiting');

      await npp.npa.sendEvent({'event': 'late'});
      expect(
          npaLogs
              .where((r) => r.level >= Level.SHOUT)
              .map((r) => r.message),
          contains(startsWith('Failed to log event late')));
    });

    test(
        'when it starts with @events as its event logging Atsign, then its'
        ' heartbeat runs, and a heartbeat carries the interval and the rule'
        ' counts at the time', () async {
      final npp = await start(eventLoggingAtSign: events);
      expect(npp.heartbeatRunning, isTrue);
      for (var i = 2; i <= 7; i++) {
        npp.nppCache.putDaemon(Daemon(atSign: '@daemon$i'));
      }

      await npp.sendHeartbeat();
      for (var i = 0; i < 50 && received.length < 2; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final heartbeat = received.singleWhere((e) => e['event'] == 'heartbeat');
      expect(heartbeat['sender'], policy);
      expect(heartbeat['policyAtsign'], policy);
      expect(heartbeat['timestamp'], endsWith('Z'));
      expect(heartbeat['interval'], 60);
      expect(heartbeat['rules'], {
        'clients': 2,
        'clientGroups': 3,
        'clientGroupMembers': 6,
        'daemons': 7,
        'services': 4,
        'serviceACLs': 5,
      });
    });

    test(
        'when it stops, then its heartbeat stops, and stopped, with the reason'
        ' and uptime, has reached @events without waiting; stopping again'
        ' sends nothing more', () async {
      final npp = await start(eventLoggingAtSign: events);

      await npp.stop(reason: 'SIGTERM');
      await npp.stop(reason: 'SIGINT');

      expect(npp.heartbeatRunning, isFalse);
      expect(eventsSent(), 2, reason: 'rulesLoaded, then one stopped');
      expect(
          npaLogs
              .map((r) => r.message)
              .where((m) => m.startsWith('Failed to log event')),
          isEmpty,
          reason: 'the second stop() does nothing, not a failed send');
      for (var i = 0; i < 50 && received.length < 2; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      expect(received.map((e) => e['event']), ['rulesLoaded', 'stopped']);
      expect(received.last['reason'], 'SIGTERM');
      expect(received.last['uptime'], greaterThanOrEqualTo(0));
    });
  });
}
