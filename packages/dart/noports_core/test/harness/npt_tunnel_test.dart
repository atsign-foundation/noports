import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:noports_core/npt.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'noports_harness.dart';

void main() {
  test('an npt tunnel through srvd with ESCR carries bytes both ways',
      () async {
    final harness = NoPortsHarness.create();
    final echo = await startEchoServer();
    await harness.startRelay();
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
        relayAuthMode: RelayAuthMode.escr,
      ),
      atClient: await harness.openClient(
        NoPortsHarness.clientAtSign,
        namespace: DefaultArgs.namespace,
      ),
    );
    addTearDown(npt.close);

    final localPort = await npt.run();
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, localPort);
    addTearDown(socket.destroy);
    final received = StringBuffer();
    final gotAll = Completer<void>();
    socket.listen((bytes) {
      received.write(utf8.decode(bytes));
      if (received.toString() == 'hello through the tunnel' &&
          !gotAll.isCompleted) {
        gotAll.complete();
      }
    });
    socket.write('hello through the tunnel');

    await gotAll.future.timeout(const Duration(seconds: 10));
    expect(received.toString(), 'hello through the tunnel');
    final relayCommands = harness.server.connections
        .where((c) => c.atSign.atSign == NoPortsHarness.relayAtSign)
        .expand((c) => c.commands);
    for (final side in [
      NoPortsHarness.clientAtSign,
      NoPortsHarness.daemonAtSign,
    ]) {
      expect(
        relayCommands,
        contains(matches(RegExp(
          '^plookup:.*_apsk\\.[^.]+\\.a\\.__e${RegExp.escape(side)}\$',
        ))),
        reason: 'the relay verifies an ESCR side with its signing key',
      );
    }
    expect(harness.server.unhandled, isEmpty);
  });
}
