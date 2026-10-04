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
import 'package:uuid/uuid.dart';

void main() {
  group('SinglePortWorker.socketHandler', () {
    late RsaKeyPair signingKP;
    late ReceivePort toMain;
    late SinglePortWorker worker;
    late ServerSocket server;
    late String sessionId;
    late String relayAuthAesKey;
    final clients = <Socket>[];

    setUpAll(() {
      signingKP = RsaKeyPair.generate(keySize: 2048);
    });

    setUp(() async {
      toMain = ReceivePort();
      worker = SinglePortWorker(
        toMain: toMain.sendPort,
        logTraffic: false,
        verbose: false,
        loggingTag: 'single port test',
        address: '127.0.0.1',
        useTLS: false,
        bindPort: 0,
      );
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(worker.socketHandler);
      sessionId = Uuid().v4();
      relayAuthAesKey = AESKey.generate(32).key;
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

    /// Starts an ESCR session between [atSignA] and [atSignB], in which every
    /// `_apsk.e.a.__e` signing key resolves to [signingKP]'s public key.
    Future<void> startSession({
      String atSignA = '@alice',
      String atSignB = '@bob',
    }) async {
      await worker.startSession(IIRequest.create(
        'start',
        SrvdSessionParams(
          sessionId: sessionId,
          atSignA: atSignA,
          atSignB: atSignB,
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
      for (final atSign in ['@alice', '@bob', '@carol']) {
        worker.sessions[sessionId]!.lookups['_apsk.e.a.__e$atSign'] =
            signingKP.atPublicKey.publicKey;
      }
    }

    /// Connects a socket that authenticates as [signer] on side A or B, and
    /// returns where the relay put it: 'pending A', 'pending B' or 'refused'.
    Future<String> connectAs(String signer, {required bool isSideA}) async {
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
        isSideA: isSideA,
      ).authenticate(socket);

      final closed = Completer<void>();
      stream!.listen(
        (_) {},
        onDone: () => closed.isCompleted ? null : closed.complete(),
        onError: (_) => closed.isCompleted ? null : closed.complete(),
      );
      final connector = worker.sessions[sessionId]!.connector!;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        if (connector.pendingA.isNotEmpty) return 'pending A';
        if (connector.pendingB.isNotEmpty) return 'pending B';
        if (closed.isCompleted) return 'refused';
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return 'undecided';
    }

    test('accepts side A signed by atSignA', () async {
      await startSession();
      expect(await connectAs('@alice', isSideA: true), 'pending A');
    });

    test('accepts side B signed by atSignB', () async {
      await startSession();
      expect(await connectAs('@bob', isSideA: false), 'pending B');
    });

    test('refuses a signer outside the session', () async {
      await startSession();
      expect(await connectAs('@carol', isSideA: true), 'refused');
    });

    test('refuses a signer claiming the other side', () async {
      await startSession();
      expect(await connectAs('@alice', isSideA: false), 'refused');
    });

    test('compares the signer with the normalised session atSigns', () async {
      await startSession(atSignA: '@Alice');
      expect(await connectAs('@alice', isSideA: true), 'pending A');
    });
  });
}
