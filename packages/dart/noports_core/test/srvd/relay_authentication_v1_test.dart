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
  group('Tests of RelayAuthenticatorV1 and RelayAuthVerifierV1', () {
    late String relayAuthAesKey;
    late String wrongAesKey;
    late String relaySessionId;
    late String publicSigningKeyUri;
    late AtEncryptionKeyPair signingKP;
    late AtEncryptionKeyPair wrongKP;
    late RelayAuthVerifyHelper helper;
    late RelayAuthVerifierV1 verifier;
    late String wrongChallenge =
        AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;

    setUpAll(() {
      signingKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      wrongKP = AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
      publicSigningKeyUri = '12345.my_enrollment_id.__wa@alice';

      relayAuthAesKey =
          AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
      wrongAesKey =
          AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
      relaySessionId = Uuid().v4();

      helper = MockRelayAuthVerifyHelper();
      when(() => helper.sessionIsActive(relaySessionId))
          .thenAnswer((_) => Future.value(true));
      when(() => helper.relayAuthAesKey(relaySessionId))
          .thenAnswer((_) => Future.value(relayAuthAesKey));
      when(() => helper.lookupAtKey(publicSigningKeyUri))
          .thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));

      verifier = RelayAuthVerifierV1('test', helper);
    });

    test('all is well', () async {
      RelayAuthenticatorV1 authenticator = RelayAuthenticatorV1(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey);
      RelayAuthVerifyHelper helper = MockRelayAuthVerifyHelper();
      RelayAuthVerifierV1 verifier = RelayAuthVerifierV1('test', helper);

      when(() => helper.sessionIsActive(relaySessionId))
          .thenAnswer((_) => Future.value(true));
      when(() => helper.relayAuthAesKey(relaySessionId))
          .thenAnswer((_) => Future.value(relayAuthAesKey));
      when(() => helper.lookupAtKey(publicSigningKeyUri))
          .thenAnswer((_) => Future.value(signingKP.atPublicKey.publicKey));

      await verifier.verifyChallengeResponse(
          authenticator.responseToChallenge(verifier.challenge));
    });

    test('wrong signing key', () async {
      RelayAuthenticatorV1 authenticator = RelayAuthenticatorV1(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: wrongKP.atPublicKey.publicKey,
          privateSigningKey: wrongKP.atPrivateKey.privateKey);

      expect(
          verifier.verifyChallengeResponse(
              authenticator.responseToChallenge(verifier.challenge)),
          throwsA(isA<RAVE>().having((e) => e.reason, 'reason',
              RAVEReason.signatureVerificationFailed)));
    });

    test('wrong AES key', () async {
      RelayAuthenticatorV1 authenticator = RelayAuthenticatorV1(
          sessionId: relaySessionId,
          relayAuthAesKey: wrongAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey);

      expect(
          verifier.verifyChallengeResponse(
              authenticator.responseToChallenge(verifier.challenge)),
          throwsA(isA<RAVE>()
              .having((e) => e.reason, 'reason', RAVEReason.decryptionFailed)));
    });

    test('wrong challenge', () async {
      RelayAuthenticatorV1 authenticator = RelayAuthenticatorV1(
          sessionId: relaySessionId,
          relayAuthAesKey: relayAuthAesKey,
          publicSigningKeyUri: publicSigningKeyUri,
          publicSigningKey: signingKP.atPublicKey.publicKey,
          privateSigningKey: signingKP.atPrivateKey.privateKey);

      expect(
          verifier.verifyChallengeResponse(
              authenticator.responseToChallenge(wrongChallenge)),
          throwsA(isA<RAVE>()
              .having((e) => e.reason, 'reason', RAVEReason.dataMismatch)
              .having((e) => e.message, 'message',
                  contains('does not match challenge issued'))));
    });
  });
}
