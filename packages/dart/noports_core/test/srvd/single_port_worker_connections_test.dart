import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:at_chops/at_chops.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

void main() {
  late RsaKeyPair signingKP;
  late ReceivePort toMain;
  late List<IIRequest> reports;
  late SinglePortWorker worker;
  late ServerSocket server;
  final clients = <Socket>[];

  setUpAll(() {
    signingKP = RsaKeyPair.generate(keySize: 2048);
  });

  setUp(() async {
    toMain = ReceivePort();
    reports = [];
    toMain.listen((m) {
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
  /// `_apsk.e.a.__e` signing key resolves to [signingKP]'s public key, and
  /// returns its relay auth key.
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
  /// or B.
  Future<Socket> connectAs(
    String sessionId,
    String relayAuthAesKey,
    String signer, {
    required bool isSideA,
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
    stream!.listen((_) {}, onError: (_) {});
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
    for (final sessionId in ['S1', 'S2']) {
      final key = await startSession(sessionId);
      final a = await connectAs(sessionId, key, '@alice', isSideA: true);
      final b = await connectAs(sessionId, key, '@bob', isSideA: false);
      sockets[sessionId] = (a, b);
    }

    for (final sessionId in ['S1', 'S2']) {
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
}
