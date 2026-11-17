import 'dart:convert';
import 'dart:isolate';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/session_crypto.dart'
    show rsaSignString;
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

void main() {
  test('createAuthVerifiers guards side A for atSignA and side B for atSignB',
      () async {
    final toMain = ReceivePort();
    final worker = PortPairWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'relay worker test',
      relayAuthDetectWindowMs: 500,
    );
    addTearDown(() {
      worker.fromMain.close();
      toMain.close();
    });

    final (a, b) = await worker.createAuthVerifiers(SrvdSessionParams(
      sessionId: 'the session',
      atSignA: '@alice',
      atSignB: '@bob',
      authenticateSocketA: true,
      authenticateSocketB: true,
      rvdNonce: 'rvd nonce',
      relayAuthMode: RelayAuthMode.escr,
      relayAuthAesKey: 'relay auth key',
      only443: false,
      multipleAcksOk: true,
      preFetch: [],
      sendJsonResponse: true,
    ));

    expect((a!.isSideA, a.atSign, a.sessionId), (true, '@alice', 'the session'));
    expect((b!.isSideA, b.atSign, b.sessionId), (false, '@bob', 'the session'));
  });

  test(
      'Given a payload-mode session requested with its id in upper case, when'
      ' a side signs the session as its client sent it, then the relay'
      ' accepts the signature', () async {
    const String sent = '0F8FAD5B-D9CB-469F-A165-70867728950E';
    final toMain = ReceivePort();
    final worker = PortPairWorker(
      toMain: toMain.sendPort,
      logTraffic: false,
      verbose: false,
      loggingTag: 'relay worker test',
      relayAuthDetectWindowMs: 500,
    );
    addTearDown(() {
      worker.fromMain.close();
      toMain.close();
    });
    final keyPair = RsaKeyPair.generate(keySize: 2048);
    final (a, _) = await worker.createAuthVerifiers(SrvdSessionParams(
      sessionId: sent.toLowerCase(),
      sessionIdAsSent: sent,
      atSignA: '@alice',
      atSignB: '@bob',
      authenticateSocketA: true,
      clientNonce: 'client nonce',
      rvdNonce: 'rvd nonce',
      relayAuthMode: RelayAuthMode.payload,
      publicKeyA: keyPair.atPublicKey.publicKey,
      only443: false,
      multipleAcksOk: true,
      preFetch: [],
      sendJsonResponse: true,
    ));
    final String signedByTheClient = jsonEncode({
      'sessionId': sent,
      'clientNonce': 'client nonce',
      'rvdNonce': 'rvd nonce',
    });
    final String envelope = jsonEncode({
      'signature': rsaSignString(signedByTheClient,
          privateKey: keyPair.atPrivateKey.privateKey),
      'hashingAlgo': HashingAlgoType.sha256.name,
      'signingAlgo': SigningAlgoType.rsa2048.name,
      'payload': jsonDecode(signedByTheClient),
    });

    expect(a!.dataToVerify, signedByTheClient);
    await RelayAuthVerifierLegacy(
      keyPair.atPublicKey.publicKey,
      a.dataToVerify,
      'rvd nonce',
      'test legacy upper case',
      '@alice'.toAtsign(),
      a.sessionId!,
    ).verifyEnvelope(envelope);
  });
}
