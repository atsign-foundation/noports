import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:noports_core/src/srvd/isolates/connection_tracker.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

void main() {
  const flush = Duration(milliseconds: 500);
  late ReceivePort toMain;
  late List<IIRequest> reports;
  late PortPairWorker worker;
  final sockets = <Socket>[];

  SrvdSessionParams session() => SrvdSessionParams(
        sessionId: 'S',
        atSignA: '@alice',
        atSignB: '@bob',
        rvdNonce: 'rvd nonce',
        only443: false,
        multipleAcksOk: true,
        preFetch: const [],
        sendJsonResponse: true,
      );

  /// A worker for session S whose reports land in [reports] once [listen]
  /// has been called.
  Future<void> start({bool listen = true}) async {
    toMain = ReceivePort();
    reports = [];
    if (listen) {
      toMain.listen((m) {
        if (m is IIRequest) reports.add(m);
      });
    }
    worker = PortPairWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'port pair connections test',
      relayAuthDetectWindowMs: 500,
      closeFlushTimeout: flush,
      connectorTimeout: const Duration(seconds: 1),
    );
    await worker.startSession(IIRequest.create('start', session()));
  }

  tearDown(() async {
    for (final s in sockets) {
      s.destroy();
    }
    sockets.clear();
    worker.connector?.close();
    worker.fromMain.close();
    toMain.close();
  });

  /// A client socket on side A and a device socket on side B, which the
  /// connector pairs.
  Future<(Socket, Socket)> pair() async {
    final client =
        await Socket.connect(InternetAddress.loopbackIPv4, worker.portA!);
    final device =
        await Socket.connect(InternetAddress.loopbackIPv4, worker.portB!);
    sockets.addAll([client, device]);
    return (client, device);
  }

  /// The [nth] report of [type], waiting up to 5 seconds for it.
  Future<IIRequest> report(String type, {int nth = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final of = reports.where((r) => r.type == type).toList();
      if (of.length >= nth) return of[nth - 1];
      await Future.delayed(const Duration(milliseconds: 10));
    }
    fail('no $type report (${reports.map((r) => r.type).toList()})');
  }

  /// Completes once [socket] has received [count] bytes.
  Future<void> received(Socket socket, int count) {
    final done = Completer<void>();
    var got = 0;
    socket.listen((data) {
      got += data.length;
      if (got >= count && !done.isCompleted) done.complete();
    });
    return done.future.timeout(const Duration(seconds: 5));
  }

  test('A worker reports a connection when its sides pair', () async {
    await start();
    final before = DateTime.timestamp().millisecondsSinceEpoch;

    final (client, device) = await pair();

    final r = await report('newConnection');
    final after = DateTime.timestamp().millisecondsSinceEpoch;
    expect(r.payload['sessionId'], 'S');
    expect(r.payload['index'], 1);
    expect(r.payload['at'], inInclusiveRange(before, after));
    expect(r.payload['client'], {'ip': '127.0.0.1', 'port': client.port});
    expect(r.payload['device'], {'ip': '127.0.0.1', 'port': device.port});
  });

  test('A worker reports a connection when both its sides are destroyed',
      () async {
    await start();
    final (client, device) = await pair();
    final paired = await report('newConnection');
    final deviceGot = received(device, 10);
    final clientGot = received(client, 20);
    client.add(Uint8List(10));
    device.add(Uint8List(20));
    await Future.wait([deviceGot, clientGot]);

    client.destroy();
    device.destroy();

    final r = await report('connectionClosed');
    expect(r.payload['sessionId'], 'S');
    expect(r.payload['index'], 1);
    expect(r.payload['openedAt'], paired.payload['at']);
    expect(r.payload['closedAt'], greaterThanOrEqualTo(paired.payload['at']));
    expect(r.payload['at'], r.payload['closedAt']);
    expect(r.payload['bytesClientToDevice'], 10);
    expect(r.payload['bytesDeviceToClient'], 20);
  });

  test(
      'Connections are numbered in the order they pair and an end names its'
      ' own start', () async {
    await start();
    final (client1, device1) = await pair();
    await report('newConnection');
    await pair();
    final second = await report('newConnection', nth: 2);
    expect(second.payload['index'], 2);

    client1.destroy();
    device1.destroy();

    final r = await report('connectionClosed');
    expect(r.payload['index'], 1);
    await Future.delayed(const Duration(milliseconds: 300));
    expect(reports.where((r) => r.type == 'connectionClosed'), hasLength(1));
    expect(worker.tracker!.openConnections, 1);
  });

  test('Event times are taken in the worker, not when main reads them',
      () async {
    await start(listen: false);
    final t0 = DateTime.timestamp().millisecondsSinceEpoch;
    final (client, device) = await pair();
    await Future.delayed(const Duration(milliseconds: 100));
    client.destroy();
    device.destroy();
    await Future.delayed(const Duration(milliseconds: 300));
    final t1 = DateTime.timestamp().millisecondsSinceEpoch;

    await Future.delayed(const Duration(seconds: 2));
    toMain.listen((m) {
      if (m is IIRequest) reports.add(m);
    });

    final paired = await report('newConnection');
    final closed = await report('connectionClosed');
    expect(paired.payload['at'], inInclusiveRange(t0, t1));
    expect(closed.payload['at'], inInclusiveRange(t0, t1));
  });

  test(
      "sessionComplete follows the last connectionClosed once the connector's"
      ' grace period has passed', () async {
    await start();
    final pairs = [await pair(), await pair(), await pair()];
    await report('newConnection', nth: 3);
    for (final (client, device) in pairs) {
      client.destroy();
      device.destroy();
    }
    await report('connectionClosed', nth: 3);

    // The connector closes itself once no connection remains and its grace
    // period, a second here, has passed.
    await worker.connector!.done.timeout(const Duration(seconds: 5));
    await worker.tracker!.complete();

    final r = await report('sessionComplete');
    expect(r.payload['connections'], 3);
    expect(r.payload['connectionsUnclosed'], 0);
    expect(r.payload['bytesClientToDevice'], 0);
    expect(r.payload['bytesDeviceToClient'], 0);
    final types = reports.map((r) => r.type).toList();
    expect(types.lastIndexOf('connectionClosed'),
        lessThan(types.indexOf('sessionComplete')));
  });

  test(
      'A side whose peer has stopped reading is destroyed within the flush'
      ' bound when the relay closes the connector', () async {
    expect(relayCloseFlushTimeout, const Duration(seconds: 3));
    expect(
      PortPairWorker(
        toMain: ReceivePort().sendPort,
        logTraffic: false,
        verbose: false,
        loggingTag: 'default bound',
        relayAuthDetectWindowMs: 500,
      ).closeFlushTimeout,
      relayCloseFlushTimeout,
      reason: 'a worker built without the parameter uses the relay bound',
    );
    await start();
    final (client, _) = await pair();
    await report('newConnection');
    // The device peer never reads, so the relay's writes toward it stall.
    for (var i = 0; i < 4; i++) {
      client.add(Uint8List(1 << 20));
    }
    await Future.delayed(const Duration(milliseconds: 500));

    final stopwatch = Stopwatch()..start();
    worker.connector!.close();

    final r = await report('connectionClosed');
    stopwatch.stop();
    expect(r.payload['index'], 1);
    expect(stopwatch.elapsed, lessThan(flush + const Duration(seconds: 2)));
  });
}
