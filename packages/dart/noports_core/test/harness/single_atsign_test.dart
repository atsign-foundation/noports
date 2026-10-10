import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/events.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'fake_atserver.dart';
import 'noports_harness.dart';

/// Lets every client of the daemon open anything the daemon allows.
class _AllowAll implements NPARequestHandler {
  _AllowAll(this.permitOpen);

  final List<String> permitOpen;

  @override
  bool hasRulesFor(Atsign daemonAtsign) => true;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest request) async =>
      NPAAuthCheckResponse(
        authorized: true,
        message: 'allowed',
        permitOpen: permitOpen,
      );
}

void main() {
  group(
      'Given one atSign @a as the client, daemon, policy service, relay and'
      ' events atSign', timeout: const Timeout(Duration(seconds: 90)), () {
    const a = '@a';

    late NoPortsHarness harness;
    late ServerSocket echo;
    late List<Map<String, dynamic>> events;
    late AtEventConfig elc;

    /// The keys of the notifications [a] has received, with ids, numbers and
    /// the event topic replaced by placeholders.
    List<String> receivedKeys() => [
          for (final n in harness.server[a].received)
            n.key
                .replaceAll(elc.topic, '<topic>')
                .replaceAll(
                  RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
                      r'[0-9a-f]{4}-[0-9a-f]{12}'),
                  '<id>',
                )
                .replaceAll(RegExp(r'\d{10,}'), '<n>'),
        ];

    /// The number of times the event-logging config shared with [a] has been
    /// written.
    int configShares() => harness.server[a].writes
        .where((k) => k == '$a:config.${DefaultArgs.eventLoggingNamespace}$a')
        .length;

    /// Waits until [a]'s received notifications stop growing for 2 s,
    /// failing if they are still growing after 10 s.
    Future<void> settles() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      var count = harness.server[a].received.length;
      var quietSince = DateTime.now();
      while (true) {
        await Future.delayed(const Duration(milliseconds: 100));
        final now = DateTime.now();
        final latest = harness.server[a].received.length;
        if (latest != count) {
          count = latest;
          quietSince = now;
        } else if (now.difference(quietSince) >= const Duration(seconds: 2)) {
          return;
        }
        if (now.isAfter(deadline)) {
          fail('$a has received $count notifications and is still receiving');
        }
      }
    }

    /// A new enrollment of [a], so each role runs as its own client, as each
    /// runs as its own process outside a test.
    FakeEnrollment role(String name) => harness.server[a].enroll(
          appName: 'noports',
          deviceName: name,
          namespaces: const {'__manage': 'rw', '*': 'rw'},
        );

    Future<void> until(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    /// Starts the events listener, the policy service and the relay, all as
    /// [a]; the daemon is started by each test.
    setUp(() async {
      harness = NoPortsHarness.create(atSigns: {a});
      echo = await startEchoServer();
      events = [];

      final listener = AtEventListenerService(
        atClient: await harness.openClient(
          a,
          namespace: DefaultArgs.namespace,
          enrollment: role('events'),
        ),
      );
      elc = await listener.getOrCreateConfig(
        namespace: DefaultArgs.eventLoggingNamespace,
        ttln: 60 * 60 * 1000,
      );
      await listener.shareEventLoggingConfigWithAtsigns(
        config: elc,
        atSigns: [a.toAtsign()],
        namespace: DefaultArgs.eventLoggingNamespace,
      );
      // NOTE the stream ends when the harness stops its client; cancelling it
      // first would wait for an event that never comes.
      listener.getJsonStream(elc).listen((json) => events.add(jsonDecode(json)));

      final policy = NPAImpl(
        atClient: await harness.openClient(
          a,
          namespace: DefaultArgs.namespace,
          enrollment: role('policy'),
        ),
        homeDirectory: harness.home.path,
        handler: _AllowAll(['127.0.0.1:${echo.port}']),
        eventLoggingAtsign: a.toAtsign(),
      );
      await policy.run();

      await harness.startRelay(atSign: a, enrollment: role('relay'));
    });

    Future<void> startDaemon() async {
      await harness.startDaemon(
        atSign: a,
        managerAtsigns: const [],
        policyAtSign: a,
        enrollment: role('daemon'),
        permitOpen: ['127.0.0.1:${echo.port}'],
      );
      await until(() => harness.daemon!.elc != null);
    }

    Future<Npt> npt() async {
      final npt = Npt.create(
        params: NptParams(
          clientAtSign: a,
          sshnpdAtSign: a,
          srvdAtSign: a,
          remoteHost: '127.0.0.1',
          remotePort: echo.port,
          device: NoPortsHarness.device,
          localPort: 0,
          localHost: '127.0.0.1',
          inline: true,
          timeout: const Duration(seconds: 30),
        ),
        atClient: await harness.openClient(
          a,
          namespace: DefaultArgs.namespace,
          enrollment: role('client'),
        ),
      );
      addTearDown(npt.close);
      return npt;
    }

    Future<String> roundTrip(int localPort, String message) async {
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, localPort);
      addTearDown(socket.destroy);
      final received = StringBuffer();
      final gotAll = Completer<void>();
      socket.listen((bytes) {
        received.write(utf8.decode(bytes));
        if (received.length >= message.length && !gotAll.isCompleted) {
          gotAll.complete();
        }
      });
      socket.write(message);
      await gotAll.future.timeout(const Duration(seconds: 10));
      return received.toString();
    }

    test(
        'when the daemon starts, then the policy service shares its'
        ' event-logging config with it once, and once things settle @a has'
        ' received exactly the notifications start-up needs', () async {
      final sharesBefore = configShares();

      await startDaemon();
      await settles();

      expect(configShares() - sharesBefore, 1);
      expect(receivedKeys(), ['@a:harness.devices.policy.sshnp@a']);
      expect(harness.server.unhandled, isEmpty);
    });

    test(
        'when the client opens an npt session through the relay and sends'
        ' data, then the data comes back, and the events listener receives'
        " that session's events", () async {
      await startDaemon();
      final session = await npt();

      final localPort = await session.run();

      expect(await roundTrip(localPort, 'one atSign'), 'one atSign');
      await until(() => events.any((e) => e['state'] == 'connected'));
      expect(
        events.map((e) => e['state']),
        containsAll(['requested', 'connected']),
      );
      expect(harness.server.unhandled, isEmpty);
    });

    test(
        'when that session ends, then once things settle @a has received'
        ' exactly the notifications the session needs', () async {
      await startDaemon();
      final session = await npt();
      final localPort = await session.run();
      expect(await roundTrip(localPort, 'one atSign'), 'one atSign');

      await session.close();
      await settles();

      expect(
        receivedKeys(),
        unorderedEquals([
          '@a:harness.devices.policy.sshnp@a',
          '@a:ping.harness.sshnp@a',
          '@a:heartbeat.harness.sshnp@a',
          '@a:harness.request_ports.sshrvd@a',
          '@a:<id>.sshrvd@a',
          '@a:harness.auth_modes.sshrvd@a',
          '@a:request.<n>.auth_checks.__rpcs.sshnp@a',
          '@a:ack.<n>.auth_checks.__rpcs.sshnp@a',
          '@a:success.<n>.auth_checks.__rpcs.sshnp@a',
          '@a:<n>.logs.policy.sshnp@a',
          '@a:npt_request.harness.sshnp@a',
          '@a:<id>.harness.sshnp@a',
          '@a:logging.<id>.sessions.sshrvd@a',
          for (var i = 0; i < 5; i++) '@a:<topic>@a',
        ]),
      );
      expect(harness.server.unhandled, isEmpty);
    });
  });
}
