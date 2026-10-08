import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' show PqPosture;
import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'noports_harness.dart';

void main() {
  /// An inline npt from the client atSign to [remotePort] on the daemon's
  /// host, closed after the test.
  Future<Npt> nptTo(
    NoPortsHarness harness,
    int remotePort, {
    RelayAuthMode relayAuthMode = RelayAuthMode.escr,
    Duration daemonPingTimeout = DefaultArgs.daemonPingTimeoutDuration,
    PqPosture posture = PqPosture.legacy,
    Set<SigningAlgoType>? dataSigningKeyAlgorithms,
  }) async {
    final npt = Npt.create(
      params: NptParams(
        clientAtSign: NoPortsHarness.clientAtSign,
        sshnpdAtSign: NoPortsHarness.daemonAtSign,
        srvdAtSign: NoPortsHarness.relayAtSign,
        remoteHost: '127.0.0.1',
        remotePort: remotePort,
        device: NoPortsHarness.device,
        localPort: 0,
        localHost: '127.0.0.1',
        inline: true,
        timeout: const Duration(seconds: 30),
        relayAuthMode: relayAuthMode,
        daemonPingTimeout: daemonPingTimeout,
      ),
      atClient: await harness.openClient(
        NoPortsHarness.clientAtSign,
        namespace: DefaultArgs.namespace,
        posture: posture,
        dataSigningKeyAlgorithms: dataSigningKeyAlgorithms,
      ),
    );
    addTearDown(npt.close);
    return npt;
  }

  /// The atSigns whose ESCR signing key the relay looked up.
  Set<String> escrVerifiedSides(NoPortsHarness harness) => {
        for (final path in harness.relayHttp.asked)
          if (RegExp(r'^/(@[^/]+)/_apsk\.[^.]+\.a\.__e$').firstMatch(path)
              case final m?)
            m.group(1)!,
      };

  /// Replaces the signing key [atSign] publishes for its first enrollment
  /// with one it doesn't hold.
  void forgeSigningKey(NoPortsHarness harness, String atSign) {
    final fake = harness.server[atSign];
    fake.recordAt('public:_apsk.${fake.firstEnrollment.id}.a.__e$atSign')!
        .value = RsaKeyPair.generate().atPublicKey.publicKey;
  }

  /// Opens a connection through the tunnel at [localPort] and waits until it
  /// has carried bytes both ways; its `ended` completes when the connection
  /// ends.
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

  /// Sends [message] into the tunnel at [localPort] and returns what comes
  /// back, failing if it hasn't all come back within 10 seconds.
  Future<String> roundTrip(int localPort, String message) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, localPort);
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

  test('an npt tunnel through srvd with ESCR carries bytes both ways',
      () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(harness, echo.port);

    final localPort = await npt.run();

    expect(
      await roundTrip(localPort, 'hello through the tunnel'),
      'hello through the tunnel',
    );
    expect(
      escrVerifiedSides(harness),
      {NoPortsHarness.clientAtSign, NoPortsHarness.daemonAtSign},
      reason: 'the relay verifies an ESCR side with its signing key',
    );
    expect(harness.server.unhandled, isEmpty);
  });

  test('post-quantum atSigns authenticate to the relay with ESCR', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay(posture: PqPosture.pqReady);
    await harness.startDaemon(
      permitOpen: ['127.0.0.1:${echo.port}'],
      posture: PqPosture.pqReady,
    );
    final npt = await nptTo(harness, echo.port, posture: PqPosture.pqReady);

    final localPort = await npt.run();

    expect(await roundTrip(localPort, 'post-quantum'), 'post-quantum');
    expect(
      escrVerifiedSides(harness),
      {NoPortsHarness.clientAtSign, NoPortsHarness.daemonAtSign},
    );
    expect(harness.server.unhandled, isEmpty);
  });

  test('atSigns that sign with ML-DSA authenticate to the relay with ESCR',
      () async {
    const mlDsa = {SigningAlgoType.mldsa65};
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay(
      posture: PqPosture.pqReady,
      dataSigningKeyAlgorithms: mlDsa,
    );
    await harness.startDaemon(
      permitOpen: ['127.0.0.1:${echo.port}'],
      posture: PqPosture.pqReady,
      dataSigningKeyAlgorithms: mlDsa,
    );
    final npt = await nptTo(
      harness,
      echo.port,
      posture: PqPosture.pqReady,
      dataSigningKeyAlgorithms: mlDsa,
    );

    final localPort = await npt.run();

    expect(await roundTrip(localPort, 'ml-dsa'), 'ml-dsa');
    expect(
      escrVerifiedSides(harness),
      {NoPortsHarness.clientAtSign, NoPortsHarness.daemonAtSign},
    );
    expect(harness.server.unhandled, isEmpty);
  });

  test('an npt tunnel with payload relay auth carries bytes both ways',
      () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(
      harness,
      echo.port,
      relayAuthMode: RelayAuthMode.payload,
    );

    final localPort = await npt.run();

    expect(await roundTrip(localPort, 'payload mode'), 'payload mode');
    expect(escrVerifiedSides(harness), isEmpty);
    expect(harness.server.unhandled, isEmpty);
  });

  test('an ESCR client and a daemon that predates ESCR share a tunnel',
      () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(
      permitOpen: ['127.0.0.1:${echo.port}'],
      advertisesEscr: false,
    );
    final npt = await nptTo(harness, echo.port);

    final localPort = await npt.run();

    expect(await roundTrip(localPort, 'mixed modes'), 'mixed modes');
    expect(escrVerifiedSides(harness), {NoPortsHarness.clientAtSign});
    expect(harness.server.unhandled, isEmpty);
  });

  test("the relay refuses a daemon whose signing key doesn't verify, and the"
      ' client reports why its session failed', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(harness, echo.port);
    forgeSigningKey(harness, NoPortsHarness.daemonAtSign);
    final started = DateTime.now();

    await expectLater(
      npt.run(),
      throwsA(isA<SshnpError>().having(
        (e) => '$e',
        'message',
        allOf(
          contains('Error response from device daemon'),
          contains('Failed to start up the daemon side of the relay socket'
              ' tunnel'),
          contains('Socket auth failed'),
        ),
      )),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 5)),
      reason: "the daemon's failure arrives, rather than a timeout",
    );
    expect(harness.server.unhandled, isEmpty);
  });

  test("a daemon signing key that doesn't verify leaves payload relay auth"
      ' working', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(
      harness,
      echo.port,
      relayAuthMode: RelayAuthMode.payload,
    );
    forgeSigningKey(harness, NoPortsHarness.daemonAtSign);

    final localPort = await npt.run();

    expect(await roundTrip(localPort, 'unsigned'), 'unsigned');
    expect(harness.server.unhandled, isEmpty);
  });

  test("a daemon whose enrollment is revoked can't serve a session, and the"
      ' relay never hears from it', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(
      harness,
      echo.port,
      daemonPingTimeout: const Duration(seconds: 2),
    );
    harness.server[NoPortsHarness.daemonAtSign].firstEnrollment.revoke();

    await expectLater(
      npt.run(),
      throwsA(isA<TimeoutException>().having(
        (e) => e.message,
        'message',
        'Daemon feature check timed out',
      )),
    );
    expect(
      escrVerifiedSides(harness),
      isNot(contains(NoPortsHarness.daemonAtSign)),
      reason: "the atServer, not the relay, keeps a revoked daemon out",
    );
    expect(harness.server.unhandled, isEmpty);
  });

  test('npt.close() ends its inline tunnel', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(harness, echo.port);
    final localPort = await npt.run();
    final live = await liveConnection(localPort);

    await npt.close();

    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, localPort),
      throwsA(isA<SocketException>()),
      reason: 'the tunnel no longer accepts connections',
    );
    await expectLater(
      live.ended.timeout(const Duration(seconds: 5)),
      completes,
      reason: 'a connection already open through the tunnel ends with it',
    );
    await expectLater(npt.done, completes);
  });

  test('relay.stop() ends the tunnels it relays', () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    final relay = await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:${echo.port}']);
    final npt = await nptTo(harness, echo.port);
    final localPort = await npt.run();
    final live = await liveConnection(localPort);

    await relay.stop();

    await expectLater(
      live.ended.timeout(const Duration(seconds: 5)),
      completes,
      reason: 'a connection through the relay ends when the relay stops',
    );
    await expectLater(
      npt.done.timeout(const Duration(seconds: 5)),
      completes,
      reason: "the client's tunnel ends with its relay",
    );
  });

  test("a destination outside the daemon's permitOpen is refused with the"
      " daemon's reason", () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
    await harness.startDaemon(permitOpen: ['127.0.0.1:1']);
    final npt = await nptTo(harness, echo.port);
    final started = DateTime.now();

    await expectLater(
      npt.run(),
      throwsA(isA<SshnpError>().having(
        (e) => '$e',
        'message',
        allOf(
          contains('Error response from device daemon'),
          contains('127.0.0.1:${echo.port} denied based on daemon'
              ' --permit-open'),
        ),
      )),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 5)),
      reason: "the daemon's refusal arrives, rather than a timeout",
    );
    expect(harness.server.unhandled, isEmpty);
  });
}
