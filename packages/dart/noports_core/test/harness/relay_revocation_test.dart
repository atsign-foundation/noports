import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:noports_core/npt.dart';
import 'package:noports_core/src/common/public_lookup.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:test/test.dart';

import 'noports_harness.dart';

void main() {
  const checkEvery = Duration(milliseconds: 200);

  /// A relay re-checking signing keys every [check], its lookups giving up
  /// after [lookupTimeout], a daemon, and an ESCR npt tunnel from the client
  /// to a loopback echo server. The atServers of the atSigns in [withoutHttp]
  /// predate HTTP GET.
  Future<({NoPortsHarness harness, SrvdImpl relay, int localPort})> tunnel({
    Duration check = checkEvery,
    Duration lookupTimeout = DirectPublicLookup.defaultTimeout,
    Set<String> withoutHttp = const {},
  }) async {
    final harness = NoPortsHarness.create();
    for (final atSign in withoutHttp) {
      harness.server[atSign].predatesHttp = true;
    }
    final echo = await startEchoServer();
    final relay = await harness.startRelay(
      signingKeyCheckInterval: check,
      lookupTimeout: lookupTimeout,
    );
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = Npt.create(
      params: NptParams(
        clientAtSign: NoPortsHarness.clientAtSign,
        sshnpdAtSign: NoPortsHarness.daemonAtSign,
        srvdAtSign: NoPortsHarness.relayAtSign,
        remoteHost: '127.0.0.1',
        remotePort: echo.port,
        device: NoPortsHarness.device,
        localPort: 0,
        localHost: '127.0.0.1',
        inline: true,
        timeout: const Duration(seconds: 30),
      ),
      atClient: await harness.openClient(
        NoPortsHarness.clientAtSign,
        namespace: DefaultArgs.namespace,
      ),
    );
    addTearDown(npt.close);
    return (harness: harness, relay: relay, localPort: await npt.run());
  }

  /// Opens a connection through the tunnel at [localPort] and waits until it
  /// has carried bytes both ways; its `ended` completes when it ends.
  Future<({Future<void> ended})> liveConnection(int localPort) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, localPort);
    addTearDown(socket.destroy);
    final echoed = Completer<void>();
    final ended = Completer<void>();
    void end([_]) {
      if (!ended.isCompleted) ended.complete();
    }

    socket.listen(
      (_) {
        if (!echoed.isCompleted) echoed.complete();
      },
      onDone: end,
      onError: end,
    );
    socket.write('live');
    await echoed.future.timeout(const Duration(seconds: 10));
    return (ended: ended.future);
  }

  /// Whether a new connection through the tunnel at [localPort] carries
  /// [message] there and back within 5 seconds.
  Future<bool> roundTrips(int localPort, String message) async {
    try {
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, localPort);
      addTearDown(socket.destroy);
      final received = StringBuffer();
      final gotAll = Completer<bool>();
      socket.listen(
        (bytes) {
          received.write(utf8.decode(bytes));
          if (received.length >= message.length && !gotAll.isCompleted) {
            gotAll.complete(received.toString() == message);
          }
        },
        onDone: () {
          if (!gotAll.isCompleted) gotAll.complete(false);
        },
        onError: (_) {
          if (!gotAll.isCompleted) gotAll.complete(false);
        },
      );
      socket.write(message);
      return await gotAll.future
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } on SocketException {
      return false;
    }
  }

  /// The `_apsk` record [atSign]'s first enrollment publishes.
  String signingKeyOf(NoPortsHarness harness, String atSign) =>
      'public:_apsk.${harness.server[atSign].firstEnrollment.id}.a.__e$atSign';

  /// How many times the relay has looked [signingKey] up from its atServer.
  /// Once a session's sockets have authenticated, only the check looks a key
  /// up again, since the session's worker keeps what it looked up.
  int rechecks(NoPortsHarness harness, String signingKey) {
    final key = signingKey.replaceFirst('public:', '');
    final at = key.lastIndexOf('@');
    final path = '/${key.substring(at)}/${key.substring(0, at)}';
    return harness.relayHttp.asked.where((asked) => asked == path).length;
  }

  /// The `_apsk` lookups the relay sent through its own atServer.
  List<String> apskPlookups(NoPortsHarness harness) => [
        for (final c in harness.server.connections)
          if (c.atSign.atSign == NoPortsHarness.relayAtSign)
            for (final command in c.commands)
              if (command.startsWith('plookup:') && command.contains('_apsk.'))
                command,
      ];

  /// Waits until [condition] holds, failing after 10 seconds.
  Future<void> eventually(String what, bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  for (final (side, atSign) in [
    ('daemon', NoPortsHarness.daemonAtSign),
    ('client', NoPortsHarness.clientAtSign),
  ]) {
    test("the relay ends a tunnel once the $side's enrollment is revoked",
        () async {
      final (:harness, :relay, :localPort) = await tunnel();
      final connection = await liveConnection(localPort);
      expect(
        relay.sessions.values.single.signingKeys,
        {
          signingKeyOf(harness, NoPortsHarness.clientAtSign),
          signingKeyOf(harness, NoPortsHarness.daemonAtSign),
        },
        reason: 'the relay recorded both sides\' signing keys',
      );

      harness.server[atSign].firstEnrollment.revoke();

      await connection.ended.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('the open connection survived the revocation'),
      );
      expect(await roundTrips(localPort, 'after'), isFalse,
          reason: 'a new connection must not get through');
      await eventually('the relay to forget the session',
          () => relay.sessions.isEmpty);
    });
  }

  test("with the check off, a revoked side's tunnel stays up, so it's the"
      " relay's check that ends one", () async {
    final (:harness, :relay, :localPort) = await tunnel(check: Duration.zero);
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));

    harness.server[NoPortsHarness.clientAtSign].firstEnrollment.revoke();
    await Future.delayed(checkEvery * 10);

    expect(ended, isFalse, reason: 'an endpoint ended the tunnel by itself');
    expect(await roundTrips(localPort, 'still up'), isTrue);
    expect(relay.sessions, hasLength(1));
  });

  test('the relay keeps a tunnel whose signing keys are still published,'
      ' re-checking them', () async {
    final (:harness, :relay, :localPort) = await tunnel();
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));
    final keys = [
      signingKeyOf(harness, NoPortsHarness.clientAtSign),
      signingKeyOf(harness, NoPortsHarness.daemonAtSign),
    ];
    final before = [for (final key in keys) rechecks(harness, key)];

    await eventually(
      'two re-checks of each signing key',
      () =>
          ended ||
          [
            for (final (i, key) in keys.indexed)
              rechecks(harness, key) - before[i],
          ].every((n) => n >= 2),
    );

    expect(ended, isFalse, reason: 'the relay ended a tunnel it should keep');
    expect(await roundTrips(localPort, 'kept'), isTrue);
    expect(relay.sessions, hasLength(1));
  });

  test("the relay keeps a tunnel while it can't reach a signer's atServer",
      () async {
    final (:harness, :relay, :localPort) = await tunnel();
    final connection = await liveConnection(localPort);
    var ended = false;
    unawaited(connection.ended.then((_) => ended = true));
    final clientKey = signingKeyOf(harness, NoPortsHarness.clientAtSign);
    final before = rechecks(harness, clientKey);

    harness.server[NoPortsHarness.clientAtSign].unreachable = true;
    await eventually('two failed re-checks of the client\'s signing key',
        () => ended || rechecks(harness, clientKey) - before >= 2);

    expect(ended, isFalse,
        reason: 'the relay ended a tunnel because a lookup failed');
    expect(apskPlookups(harness), isEmpty,
        reason: "a re-check never asks the relay's own atServer");
    expect(await roundTrips(localPort, 'kept'), isTrue);
    expect(relay.sessions, hasLength(1));
  });

  test("the relay ends a revoked client's tunnel while the daemon's atServer"
      ' leaves its re-checks unanswered', () async {
    final (:harness, relay: _, :localPort) =
        await tunnel(lookupTimeout: const Duration(seconds: 8));
    final connection = await liveConnection(localPort);
    final clientKey = signingKeyOf(harness, NoPortsHarness.clientAtSign);
    final daemonKey = signingKeyOf(harness, NoPortsHarness.daemonAtSign);
    final daemonRechecksBefore = rechecks(harness, daemonKey);

    harness.server[NoPortsHarness.daemonAtSign].silent = true;
    harness.server[NoPortsHarness.clientAtSign].firstEnrollment.revoke();

    await connection.ended.timeout(
      const Duration(seconds: 4),
      onTimeout: () => fail('the tunnel outlived the revocation by 4 s'),
    );
    expect(rechecks(harness, daemonKey), greaterThan(daemonRechecksBefore),
        reason: "a re-check of the daemon's key was left unanswered");
    expect(rechecks(harness, clientKey), greaterThan(1),
        reason: "the relay looked the client's key up over HTTP");
    expect(apskPlookups(harness), isEmpty,
        reason: 'no lookup went through the relay\'s own atServer');
  });

  test('the relay authenticates a side whose atServer predates HTTP GET,'
      ' through its own atServer', () async {
    final (:harness, relay: _, :localPort) =
        await tunnel(withoutHttp: {NoPortsHarness.daemonAtSign});

    await liveConnection(localPort);
    expect(
      apskPlookups(harness),
      contains(endsWith(signingKeyOf(harness, NoPortsHarness.daemonAtSign)
          .replaceFirst('public:', ''))),
    );
  });
}
