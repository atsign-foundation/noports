import 'dart:async';
import 'dart:io';
import 'package:at_chops/at_chops.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class MockRelayAuthVerifyHelper extends Mock implements RelayAuthVerifyHelper {}

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

void main() {
  group('Tests of RelayAuthenticatorESCR and RelayAuthVerifierESCR', () {
    late String relayAuthAesKey;
    late String wrongAesKey;
    late String relaySessionId;
    late String publicSigningKeyUri;
    late AtEncryptionKeyPair signingKP;
    late AtEncryptionKeyPair wrongKP;
    late RelayAuthVerifyHelper helper;
    late String wrongChallenge = AtChopsUtil.generateSymmetricKey(
      EncryptionKeyType.aes256,
    ).key;

    setUpAll(() {
      signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      wrongKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      publicSigningKeyUri = '_apsk.my_enrollment_id.a.__e@alice';

      relayAuthAesKey = AtChopsUtil.generateSymmetricKey(
        EncryptionKeyType.aes256,
      ).key;
      wrongAesKey = AtChopsUtil.generateSymmetricKey(
        EncryptionKeyType.aes256,
      ).key;
      relaySessionId = Uuid().v4();

      helper = MockRelayAuthVerifyHelper();
      when(
        () => helper.isSessionActive(relaySessionId),
      ).thenAnswer((_) => Future.value(true));
      when(
        () => helper.getRelayAuthAesKey(relaySessionId),
      ).thenAnswer((_) => Future.value(relayAuthAesKey));
      when(
        () => helper.lookup(relaySessionId, publicSigningKeyUri),
      ).thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));
    });

    test('all is well', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: false,
      );
      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test all is well',
        helper,
      );

      when(
        () => helper.isSessionActive(relaySessionId),
      ).thenAnswer((_) => Future.value(true));
      when(
        () => helper.getRelayAuthAesKey(relaySessionId),
      ).thenAnswer((_) => Future.value(relayAuthAesKey));
      when(
        () => helper.lookup(relaySessionId, publicSigningKeyUri),
      ).thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));

      expect(verifier.atSign, isNull);
      expect(verifier.sessionId, isNull);
      expect(verifier.isSideA, null);

      bool verified = await verifier.verifyChallengeResponse(
        authenticator.responseToChallenge(verifier.challenge),
      );

      expect(verified, true);
      expect(verifier.atSign, '@alice');
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, false);
    });

    test('wrong signing key', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: wrongKP.atPublicKey.publicKey,
        privateSigningKey: wrongKP.atPrivateKey.privateKey,
        isSideA: true,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong signing key',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          authenticator.responseToChallenge(verifier.challenge),
        ),
        throwsA(
          isA<RAVE>().having(
            (e) => e.reason,
            'reason',
            RAVEReason.signatureVerificationFailed,
          ),
        ),
      );

      expect(verifier.atSign, '@alice');
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, true);
    });

    test('wrong AES key', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: wrongAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: true,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong AES key',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          authenticator.responseToChallenge(verifier.challenge),
        ),
        throwsA(
          isA<RAVE>().having(
            (e) => e.reason,
            'reason',
            RAVEReason.decryptionFailed,
          ),
        ),
      );

      expect(verifier.atSign, null);
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, null);
    });

    test('wrong challenge', () async {
      RelayAuthenticatorESCR authenticator = RelayAuthenticatorESCR(
        sessionId: relaySessionId,
        relayAuthAesKey: relayAuthAesKey,
        publicSigningKeyUri: publicSigningKeyUri,
        publicSigningKey: signingKP.atPublicKey.publicKey,
        privateSigningKey: signingKP.atPrivateKey.privateKey,
        isSideA: false,
      );

      RelayAuthVerifierESCR verifier = RelayAuthVerifierESCR(
        'test wrong challenge',
        helper,
      );

      await expectLater(
        verifier.verifyChallengeResponse(
          authenticator.responseToChallenge(wrongChallenge),
        ),
        throwsA(
          isA<RAVE>()
              .having((e) => e.reason, 'reason', RAVEReason.dataMismatch)
              .having(
                (e) => e.message,
                'message',
                contains('does not match challenge issued'),
              ),
        ),
      );

      expect(verifier.atSign, null);
      expect(verifier.sessionId, relaySessionId);
      expect(verifier.isSideA, false);
    });
  });
}
