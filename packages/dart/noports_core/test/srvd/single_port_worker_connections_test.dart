import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_chops/at_chops.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/isolates/connection_tracker.dart'
    show stopReportBound;
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

const s1 = '51000000-0000-4000-8000-000000000001';
const s2 = '52000000-0000-4000-8000-000000000002';

void main() {
  late RsaKeyPair signingKP;
  late ReceivePort toMain;
  late List<IIRequest> reports;
  late List<String> arrivals;
  late SinglePortWorker worker;
  late ServerSocket server;
  final clients = <Socket>[];
  final reading = <Socket, StreamSubscription<dynamic>>{};

  setUpAll(() {
    signingKP = RsaKeyPair.generate(keySize: 2048);
  });

  setUp(() async {
    toMain = ReceivePort();
    reports = [];
    arrivals = [];
    toMain.listen((m) {
      arrivals.add(m is IIRequest ? m.type : '$m');
      if (m is IIRequest) reports.add(m);
    });
    worker = SinglePortWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'single port connections test',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
      closeFlushTimeout: const Duration(milliseconds: 500),
      connectorTimeout: const Duration(seconds: 1),
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(worker.socketHandler);
  });

  tearDown(() async {
    for (final c in clients) {
      c.destroy();
    }
    clients.clear();
    for (final si in worker.sessions.values) {
      si.connector?.close();
    }
    await server.close();
    worker.fromMain.close();
    toMain.close();
  });

  /// Starts ESCR session [sessionId] between @alice and @bob, in which every
  /// `_apsk.e.a.__e` client data signing key resolves to [signingKP]'s public
  /// key, and returns its relay auth key.
  Future<String> startSession(String sessionId) async {
    final relayAuthAesKey = AESKey.generate(32).key;
    await worker.startSession(IIRequest.create(
      'start',
      SrvdSessionParams(
        sessionId: sessionId,
        atSignA: '@alice',
        atSignB: '@bob',
        authenticateSocketA: true,
        authenticateSocketB: true,
        rvdNonce: 'rvd nonce',
        relayAuthMode: RelayAuthMode.escr,
        relayAuthAesKey: relayAuthAesKey,
        only443: true,
        multipleAcksOk: true,
        preFetch: [],
        sendJsonResponse: true,
      ),
    ));
    for (final atSign in ['@alice', '@bob']) {
      worker.sessions[sessionId]!.lookups['_apsk.e.a.__e$atSign'] =
          signingKP.atPublicKey.publicKey;
    }
    return relayAuthAesKey;
  }

  /// Connects a socket to [sessionId] authenticating as [signer] on side A
  /// or B, which reads nothing once authenticated unless [reads].
  Future<Socket> connectAs(
    String sessionId,
    String relayAuthAesKey,
    String signer, {
    required bool isSideA,
    bool reads = true,
  }) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    clients.add(socket);
    final (_, stream) = await RelayAuthenticatorESCR(
      sessionId: sessionId,
      relayAuthAesKey: relayAuthAesKey,
      publicSigningKeyUri: '_apsk.e.a.__e$signer',
      publicSigningKey: signingKP.atPublicKey.publicKey,
      privateSigningKey: signingKP.atPrivateKey.privateKey,
      signingAlgo: SigningAlgoType.rsa2048,
      isSideA: isSideA,
    ).authenticate(socket);
    final subscription = stream!.listen((_) {}, onError: (_) {});
    if (!reads) subscription.pause();
    reading[socket] = subscription;
    return socket;
  }

  /// The reports of [type] for [sessionId], waiting up to 5 seconds for
  /// [count] of them.
  Future<List<IIRequest>> reportsFor(
    String type,
    String sessionId, {
    int count = 1,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final of = reports
          .where((r) => r.type == type && r.payload['sessionId'] == sessionId)
          .toList();
      if (of.length >= count) return of;
      await Future.delayed(const Duration(milliseconds: 10));
    }
    fail('no $type for $sessionId (${reports.map((r) => r.type).toList()})');
  }

  test(
      'The port-443 worker reports the same messages for each of its'
      ' sessions', () async {
    final sockets = <String, (Socket, Socket)>{};
    for (final sessionId in [s1, s2]) {
      final key = await startSession(sessionId);
      final a = await connectAs(sessionId, key, '@alice', isSideA: true);
      final b = await connectAs(sessionId, key, '@bob', isSideA: false);
      sockets[sessionId] = (a, b);
    }

    for (final sessionId in [s1, s2]) {
      final paired = await reportsFor('newConnection', sessionId);
      expect(paired.single.payload['index'], 1);
      final (a, b) = sockets[sessionId]!;
      a.destroy();
      b.destroy();
      final closed = await reportsFor('connectionClosed', sessionId);
      expect(closed.single.payload['index'], 1);
      final complete = await reportsFor('sessionComplete', sessionId);
      expect(complete.single.payload['connections'], 1);
      expect(complete.single.payload['connectionsUnclosed'], 0);
    }
    expect(reports.where((r) => r.type == 'newConnection'), hasLength(2));
    expect(reports.where((r) => r.type == 'connectionClosed'), hasLength(2));
  });

  test(
      'A stop of the port-443 worker reports each session complete before'
      ' the worker exits', () async {
    final key = await startSession(s1);
    final a = await connectAs(s1, key, '@alice', isSideA: true);
    await connectAs(s1, key, '@bob', isSideA: false);
    await reportsFor('newConnection', s1);
    unawaited(a.done.then((_) {}, onError: (_) {}));
    a.add(List<int>.filled(1 << 22, 7));
    unawaited(worker.stopped.future.then((_) => toMain.sendPort.send('exit')));

    await worker.stop();

    await reportsFor('sessionComplete', s1);
    final exitAt = await () async {
      while (!arrivals.contains('exit')) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return arrivals.indexOf('exit');
    }();
    expect(arrivals.indexOf('sessionComplete'), lessThan(exitAt),
        reason: 'run() kills the isolate once stopped completes');
  });

  /// A worker that gives a closing side the default 30 seconds to take its
  /// pending data, in place of the one [setUp] built.
  Future<void> withDefaultFlush() async {
    worker.fromMain.close();
    await server.close();
    worker = SinglePortWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'single port connections test',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
      connectorTimeout: const Duration(seconds: 1),
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(worker.socketHandler);
  }

  test(
      'Given a single-port connection whose client has closed while data still'
      ' waits for its device, when the session is ended for a withdrawn key,'
      ' then the connection is closed and the session reported complete'
      ' within a second', () async {
    await withDefaultFlush();
    const int sent = 3900000;
    final key = await startSession(s1);
    final a = await connectAs(s1, key, '@alice', isSideA: true);
    await connectAs(s1, key, '@bob', isSideA: false, reads: false);
    await reportsFor('newConnection', s1);
    a.add(List<int>.filled(sent, 7));
    await a.close();
    final connector = worker.sessions[s1]!.connector!;
    final DateTime giveUp = DateTime.now().add(const Duration(seconds: 5));
    while (connector.connections.isNotEmpty &&
        DateTime.now().isBefore(giveUp)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(connector.connections, isEmpty,
        reason: 'the connection is ending, its device side still draining');
    expect(reports.where((r) => r.type == 'connectionClosed'), isEmpty,
        reason: 'the control: nothing has closed it yet');

    final stopwatch = Stopwatch()..start();
    await worker.reqHandlers['endSession']!(
        IIRequest.create('endSession', s1));
    await reportsFor('connectionClosed', s1);
    await reportsFor('sessionComplete', s1);

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'its 30 seconds to drain are cut short');
  });

  test(
      'Given a single-port session that has already finished, when it is'
      ' ended for a withdrawn key, then nothing happens', () async {
    final key = await startSession(s1);
    final a = await connectAs(s1, key, '@alice', isSideA: true);
    final b = await connectAs(s1, key, '@bob', isSideA: false);
    await reportsFor('newConnection', s1);
    a.destroy();
    b.destroy();
    await reportsFor('sessionComplete', s1);
    expect(worker.sessions.containsKey(s1), isFalse,
        reason: 'the session is gone from the worker');

    await worker.reqHandlers['endSession']!(
        IIRequest.create('endSession', s1));

    expect(reports.where((r) => r.type == 'sessionComplete'), hasLength(1));
  });

  test(
      'A single-port session ended for a withdrawn key has its sockets closed'
      ' at once', () async {
    worker.fromMain.close();
    await server.close();
    worker = SinglePortWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'single port connections test',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
      connectorTimeout: const Duration(seconds: 1),
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(worker.socketHandler);
    const int sent = 64 * 1024 * 1024;
    final key1 = await startSession(s1);
    final a1 = await connectAs(s1, key1, '@alice', isSideA: true);
    final b1 =
        await connectAs(s1, key1, '@bob', isSideA: false, reads: false);
    final key2 = await startSession(s2);
    final a2 = await connectAs(s2, key2, '@alice', isSideA: true);
    final b2 = await connectAs(s2, key2, '@bob', isSideA: false);
    await reportsFor('newConnection', s1);
    await reportsFor('newConnection', s2);
    unawaited(a1.done.then((_) {}, onError: (_) {}));
    a1.add(List<int>.filled(sent, 7));
    await Future<void>.delayed(const Duration(seconds: 1));

    final stopwatch = Stopwatch()..start();
    await worker.reqHandlers['endSession']!(
        IIRequest.create('endSession', s1));
    await reading[a1]!
        .asFuture<void>()
        .catchError((_) {})
        .timeout(const Duration(seconds: 5));
    final complete = (await reportsFor('sessionComplete', s1)).single.payload;
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'the client side is closed and the session reported complete');
    expect(complete['bytesClientToDevice'], greaterThan(0));
    var deviceFoundItClosed = false;
    unawaited(b1.done.then((_) => deviceFoundItClosed = true,
        onError: (_) => deviceFoundItClosed = true));
    while (!deviceFoundItClosed &&
        stopwatch.elapsed < const Duration(seconds: 1)) {
      try {
        b1.add([0]);
      } catch (_) {
        deviceFoundItClosed = true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(deviceFoundItClosed, isTrue,
        reason: 'the side that reads nothing has lost its socket too: a'
            ' write to it fails');
    var took = 0;
    reading[b1]!
      ..onData((data) => took += (data as List<int>).length)
      ..resume();
    await reading[b1]!
        .asFuture<void>()
        .catchError((_) {})
        .timeout(const Duration(seconds: 5));

    expect(took, lessThan(sent),
        reason: 'what was still waiting for the device was dropped');
    var carried = 0;
    reading[b2]!.onData((data) => carried += (data as List<int>).length);
    a2.add(List<int>.filled(1024, 7));
    await a2.flush();
    final DateTime giveUp = DateTime.now().add(const Duration(seconds: 5));
    while (carried < 1024 && DateTime.now().isBefore(giveUp)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(carried, 1024, reason: 'the other session carries on');
    expect(reports.where((r) =>
        r.type == 'sessionComplete' && r.payload['sessionId'] == s2), isEmpty);
  });

  test(
      'A session whose device stops reading is reported complete before its'
      ' worker is killed', () async {
    worker.fromMain.close();
    await server.close();
    worker = SinglePortWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'single port connections test',
      address: '127.0.0.1',
      useTLS: false,
      bindPort: 0,
      connectorTimeout: const Duration(seconds: 1),
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(worker.socketHandler);
    final key = await startSession(s1);
    final a = await connectAs(s1, key, '@alice', isSideA: true);
    await connectAs(s1, key, '@bob', isSideA: false, reads: false);
    await reportsFor('newConnection', s1);
    unawaited(a.done.then((_) {}, onError: (_) {}));
    a.add(List<int>.filled(64 * 1024 * 1024, 7));
    await Future<void>.delayed(const Duration(seconds: 1));
    final stopwatch = Stopwatch()..start();

    unawaited(worker.stop());
    bool reported() => reports.any((r) => r.type == 'sessionComplete');
    final DateTime giveUp = DateTime.now().add(const Duration(seconds: 10));
    while (!reported() && DateTime.now().isBefore(giveUp)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    stopwatch.stop();
    expect(stopwatch.elapsed,
        lessThan(stopReportBound + const Duration(milliseconds: 500)),
        reason: 'the session is reported complete within the report bound');
    final complete =
        reports.where((r) => r.type == 'sessionComplete').single.payload;
    expect(complete['connectionsUnclosed'], 1);
    expect(complete['bytesClientToDevice'], greaterThan(0));
  });
}
