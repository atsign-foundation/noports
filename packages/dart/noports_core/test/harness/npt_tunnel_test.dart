import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      ),
      atClient: await harness.openClient(
        NoPortsHarness.clientAtSign,
        namespace: DefaultArgs.namespace,
      ),
    );
    addTearDown(npt.close);
    return npt;
  }

  /// The atSigns whose ESCR signing key the relay looked up.
  Set<String> escrVerifiedSides(NoPortsHarness harness) => {
        for (final c in harness.server.connections)
          if (c.atSign.atSign == NoPortsHarness.relayAtSign)
            for (final command in c.commands)
              if (RegExp(r'^plookup:.*_apsk\.[^.]+\.a\.__e(@[^@]+)$')
                      .firstMatch(command)
                  case final m?)
                m.group(1)!,
      };

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
