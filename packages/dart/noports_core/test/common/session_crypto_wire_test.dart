import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

// Raw-literal pins of what NoPorts puts on the wire, and reads off it. Every
// expected value below was produced by at_chops's deprecated AtChops path,
// which is what every released NoPorts binary signs and encrypts with, so
// these are frozen: a change here is a wire change, and editing a pin in the
// same commit as the code is the review.

const String _publicKey = r'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1XUBuiQgiIkWmykKHLtUz2Bhi6moVernBXXslu29OhfKTSszv9em4a6cOXl+XnhTGbwpcUnCUkAX4b4rWOzH6J80I8E/H7+jLprj99N9+K5Inn6yZO7EiYG4o6QXGHZeUo63hGzJyexAszHCNDLIEULkzfW+byPin5lpIO0HjfMR2FcryQw6cWtAVAiSLYzVNRBYClQSCILY7TLgKE2hZhuSZ/b3HjmfSVIbN549ljd2EClrQua56Ce14WNmDCkrq3YlFxngkw7nhyBTSvEraltVHE2ChQ/xnwVqAY8pH3r4JNHeBAm5JNMvIfJ3qJ3Mbz0vUtoi0xu2+GeeXHw0HwIDAQAB';
const String _privateKey = r'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDVdQG6JCCIiRabKQocu1TPYGGLqahV6ucFdeyW7b06F8pNKzO/16bhrpw5eX5eeFMZvClxScJSQBfhvitY7MfonzQjwT8fv6MumuP30334rkiefrJk7sSJgbijpBcYdl5SjreEbMnJ7ECzMcI0MsgRQuTN9b5vI+KfmWkg7QeN8xHYVyvJDDpxa0BUCJItjNU1EFgKVBIIgtjtMuAoTaFmG5Jn9vceOZ9JUhs3nj2WN3YQKWtC5rnoJ7XhY2YMKSurdiUXGeCTDueHIFNK8StqW1UcTYKFD/GfBWoBjykfevgk0d4ECbkk0y8h8neoncxvPS9S2iLTG7b4Z55cfDQfAgMBAAECggEADn2X9Wv4bWxpBXV+wz6QXlebp6CH1fVRY5SC0CgpfWUaDa0OIUrhgFabMmemBYHDmm6knZU1ROIm/OMtDCde1tLf9kFrKJuY11Qaf7tyxMwIEAJn1+RBoVgWEb3U94spkg8wNCQyequ4JLIPDf4YiNtyruys1dyoyM7gTSTqK1+iJpObEXr2aahjpTHM1IE3dYkX5ua+WDMBVTWLqacekMU81NLXlyCT5/Fp5xAwurvOaEJ1a2QHIkPqF7apTJKDNsqc4TB+0f12YMHvLAYB24HUnHCnggXnEvfXWD2R6meKIzMJpFkCFjY4K12kStMWwt5bI84LpRqeqaGwaQdwuQKBgQDyyxY3XcEdOLPRfX287oh4UupIAlQChPKOXpMh8V9LJize8yGlEiIvYSPAReKoAAIaqa8cvVc1UAGWMQEgrYMD+DYQhFInLRFS5aRErduienOT9Pyi3r/6EgNLXDW3UYoATr65tACGPaWABnb311+Lvivdh45c+hfH/PLQJRVqTQKBgQDhEWkjik5mb4HJi/GK0/zxLk0bmOivTwIxHJWuQ6j8x6AfdRUNWFLgBkGyqrjG2KMx2hXbyyjVpxtX0BpmyaDuXzFeaO0gFMit4O8zYn8+n0AwMTKcLC/LxQAlM2xPG9NcYBsIunMMoCe8QCWcNz3Q8w96SzLyYDi2SjWuPWT2GwKBgCMFMh4oUsuROzazYCiZS2v3ob1jQJTgclAgyh4yP6mKRxydezPhKrckztBUBD5xSdxor0547RROhvwP83awMF6pNbsqKuNlt8L6Rrh1T2HfQb6MrsgbUxuR75G2KjVX+IzUzuPgV9cFG1MdG5niIfD5LECW5ez5UebR0IA/aRhdAoGAZmzm/S6XCVUbqp5OWVCqHxRkMPgAhK+fHryUfc7627b5bvd4ki8s4BjY0zeQiaXTdv95zSICvmCjN+5T5Y1C+NhHfmCf8WakAUWJdkgQAm605nmtP5d4VPKdY1CorMPMB5ERHILFkuxbyPckZphZQHstAwmv8M/LX2IcVeRIyxsCgYEA8XLLSuFuo87BHCKGYgBpJglavbmRykQxIFeRdRj5FPgGgIK09BX7vsyCHcjPXOkvXRGZmI8NynUiouuEf7aK7H68/Ndv9HRFiClwAUJ3i/VbIb2N3fCMomHMGdV9qS6mwEnMU8HASNkiNu7jSl5D2zd6wGZ4V+2bG75b7Bvwj8U=';

const Map<String, String> _payload = {
  'sessionId': '6f1c2a3b-0d4e-4f5a-8b9c-1d2e3f4a5b6c',
  'clientNonce': '2026-09-30T11:00:00.000Z',
  'rvdNonce': 'é✓ nonce',
};
const String _envelope = r'{"payload":{"sessionId":"6f1c2a3b-0d4e-4f5a-8b9c-1d2e3f4a5b6c","clientNonce":"2026-09-30T11:00:00.000Z","rvdNonce":"é✓ nonce"},"signature":"dbD+w+iQAJgKC4o/EwjI3KKMlpcvjO4SgHCN/IRviKU+ck4PMFLQ1U7tzPRdyi2ixI7sgYy5OJBBNdhNbgjiWRfEAB5GZRXzeWIU/3jwg99fG37JU0JruNsiIHXF3AJUgj7j1EQnwbBPMILo62n1cBEnTWvoc7icx7X0nPcwOeOixdqvm2Br8KYHS/KMlDPM+h3NHVA8PVJMdEhRsbtF76sqfOCHH5nZr3UwDvTiqxU+sdcvclFoVcznjj92BWyVL+r3Vc3G4BzEpfmkiU8t/GKgP7LYQuArnb5NVQ4UlAQdF26cI1PN8XpF8fuTj4B1wH5+xqIbo/NOBVROGt0ykQ==","hashingAlgo":"sha256","signingAlgo":"rsa2048"}';

const Map<String, String> _escrP = {
  'sid': 'escr-session',
  'c': 'the-challenge',
  'side': 'a',
};
const String _escrSignature = r'DNMLgt7sHeC/g1cOcnXyvBpKURZF9pq2/nKYFvOMadvNoNx1o/hfdoufdMlyucEjSx/1N/IK9/Hrm77Nulc0d5waopsCWQng+J0ypKDZTr8I49I49QYYvOulSd5jxVkr6MhEn5qIwfWvXSPsnMuj4plMpb9M/9bmLWlM1mdzzGuyzZ41fnsuOrOamlnribZjaaxhgoNQwVUpNiMScBtqLo+k/hy3RjhxR9cVDCqVXy8xsilHffuurQXdr6Hjl79cV93tiTLPYenErCOony5ydknV95aUxK0lCjQxoQan4vKanCa+8SR/veiJ1W3KTUF3GkDx4tsPtngndxYGXLTxkQ==';
const String _escrKeyUri = 'public:_apsk.primary.a.__e@alice';

const String _aesKey = 'Kq0jN2pQ9vW4xY7zA1bC3dE5fG6hI8jK0lM2nO4pQ6s=';
const String _ivBase64 = 'AAECAwQFBgcICQoLDA0ODw==';
const String _aesCiphertext = r'5tAyUXl4z+Qr7zniScf15eR5kq5ybVfPhZvQ1/Nlwtw=';

const String _rsaCiphertext = r'T/nFvv4CwpNt1qiLfFWNqP6GADhCbF4V+88EXkIcL5G9rAotVDShO8buszjrfnBu4/0J+hjVvI/OvofEM3VW+oK86iYW7lrGSdnuCzSvIx+4isC7FKHH8wlD/emkaJEoSjiaiEuK+5dwLiFvrl5tWLM4t1AgR/u0mttBnOs27weoPWs3gMhgrnjZ7X18SRMoSMXxGRnUtUJMXtmsPWj26sYXxDgzvmpO34hgFHqnhTAR4zZt4q/8gVOXtzyDNlLKI6OBzJzevsY0IDmI5EUftE0KG3KxPafmqBaKJGqLwnwTB/EVf3M+e2i3pyLDCYPdmMBHYqqBHego7hfBmNf6UQ==';

const String _publicKey1024 = r'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCR4GCIbv4D+l8HDe755xJMHlairvEonRsidKcPI53MC9734C1muOmnAlcBMs6htBKNAgllnLuREdWoM936onRrHPpLwc4uGjel3DhMBCsJXi8qglCLjGzESwqYzHuQE4xojEAcYs/8KXZpw+YzcqnldcLPosENLxxCQZCCC6oUpQIDAQAB';
const String _signature1024 = r'gV1UaPnTZLw6qFX0PjvgW2BgPFrAmLgEPKkoebhH2OyYe0Z7whqXErDm+sjRjHcSShtuyS6F/rRifXCKo+IHB5D/F3V/zPssP/EqxSVkGLfotPO/7S+U11wop3GHV1fk1WuPxFBA/S0sS6fJmVFwZpJlOUWiVsaomLC6EGw9xak=';

class _Signer with ApkamSigning {
  @override
  final AtClient atClient;
  @override
  final AtSignLogger logger = AtSignLogger('session_crypto_wire_test');
  _Signer(this.atClient);
}

void main() {
  final keyPair = RsaKeyPair.create(_publicKey, _privateKey);

  setUpAll(() {
    registerFallbackValue(AtKey());
  });

  group('wire pins', () {
    test('signAndWrapAndJsonEncode produces the released envelope', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      stubEncryptionKeys(client, keyPair);
      expect(await signAndWrapAndJsonEncode(client, _payload), _envelope);
    });

    test('the ESCR signature over p is the released one', () {
      expect(
        rsaSignString(jsonEncode(_escrP), privateKey: _privateKey),
        _escrSignature,
      );
    });

    test('the ESCR response carries the released inner envelope', () async {
      final response = await RelayAuthenticatorESCR(
        sessionId: 'escr-session',
        relayAuthAesKey: _aesKey,
        publicSigningKeyUri: _escrKeyUri,
        publicSigningKey: _publicKey,
        privateSigningKey: _privateKey,
        isSideA: true,
      ).responseToChallenge('the-challenge');

      expect(response, startsWith('escr-session:'));
      final outer = jsonDecode(
        utf8.decode(base64Decode(response.substring('escr-session:'.length))),
      );
      final envelope64 = await aesDecryptString(
        outer['e'],
        key: _aesKey,
        iv: InitialisationVector(base64Decode(outer['iv'])),
      );
      expect(
        String.fromCharCodes(base64Decode(envelope64)),
        jsonEncode({
          'p': _escrP,
          's': _escrSignature,
          'ha': 'sha256',
          'sa': 'rsa2048',
          'sk': _escrKeyUri,
        }),
      );
    });

    test('AES encryption matches the released ciphertext', () async {
      expect(
        await aesEncryptString(
          'envelope64-é✓',
          key: _aesKey,
          iv: InitialisationVector(base64Decode(_ivBase64)),
        ),
        _aesCiphertext,
      );
    });

    test('a released RSA session-key ciphertext decrypts', () {
      expect(
        rsaDecryptString(_rsaCiphertext, keyPair: keyPair),
        'session-aes-key',
      );
    });
  });

  group('verification', () {
    test('accepts a released signature', () async {
      expect(
        await rsaVerifyString(
          jsonEncode(_escrP),
          signature: _escrSignature,
          publicKey: _publicKey,
          hashing: HashingAlgoType.sha256,
        ),
        true,
      );
    });

    test('rejects a key that is not 2048-bit RSA, however validly signed',
        () async {
      expect(
        await rsaVerifyString(
          'x',
          signature: _signature1024,
          publicKey: _publicKey1024,
          hashing: HashingAlgoType.sha256,
        ),
        false,
      );
    });

    test('verifyEnvelopeSignature accepts the released envelope', () async {
      final client = MockAtClient();
      when(() => client.get(any()))
          .thenAnswer((_) async => AtValue()..value = _publicKey);
      await verifyEnvelopeSignature(
        client,
        '@alice',
        AtSignLogger('test'),
        jsonDecode(_envelope),
      );
    });

    for (final label in ['rsa4096', 'ecc_secp256r1']) {
      test('verifyEnvelopeSignature refuses signingAlgo $label before any '
          'lookup', () async {
        final client = MockAtClient();
        when(() => client.get(any()))
            .thenAnswer((_) async => AtValue()..value = _publicKey);
        final envelope = jsonDecode(_envelope)..['signingAlgo'] = label;
        await expectLater(
          verifyEnvelopeSignature(
            client,
            '@alice',
            AtSignLogger('test'),
            envelope,
          ),
          throwsA(isA<AtSigningVerificationException>()),
        );
        verifyNever(() => client.get(any()));
      });
    }
  });

  group('the signing keypair source', () {
    test('a client with no key source cannot sign', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      when(() => client.atKeysIo).thenReturn(null);
      await expectLater(
        signAndWrapAndJsonEncode(client, _payload),
        throwsA(isA<AtClientException>()),
      );
    });

    test('keys without an encryption keypair cannot sign', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      when(() => client.atKeysIo).thenReturn(
        InMemoryAtKeysIo.holding('@alice', AtKeys.legacy(selfEncryptionKey: _aesKey)),
      );
      await expectLater(
        signAndWrapAndJsonEncode(client, _payload),
        throwsA(isA<AtClientException>()),
      );
    });

    test('the keypair is read once per client and atSign', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      stubEncryptionKeys(client, keyPair);
      await signAndWrapAndJsonEncode(client, _payload);

      when(() => client.atKeysIo).thenReturn(null);
      expect(await signAndWrapAndJsonEncode(client, _payload), _envelope);

      when(() => client.getCurrentAtSign()).thenReturn('@bob');
      await expectLater(
        signAndWrapAndJsonEncode(client, _payload),
        throwsA(isA<AtClientException>()),
      );
    });
  });

  group('escrSigningKeyPair', () {
    test('is the APKAM authentication keypair from the keyfile', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      when(() => client.enrollmentId).thenReturn(null);
      when(() => client.getPreferences()).thenReturn(null);
      when(() => client.atKeysIo).thenReturn(
        InMemoryAtKeysIo.holding(
          '@alice',
          AtKeys.legacy(apkamPublicKey: _publicKey, apkamPrivateKey: _privateKey),
        ),
      );
      final pair = await escrSigningKeyPair(_Signer(client));
      expect(pair.publicKey, _publicKey);
      expect(pair.privateKey, _privateKey);
    });

    test('throws when the client holds no APKAM keypair', () async {
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn('@alice');
      when(() => client.enrollmentId).thenReturn(null);
      when(() => client.getPreferences()).thenReturn(null);
      when(() => client.atKeysIo).thenReturn(
        InMemoryAtKeysIo.holding('@alice', AtKeys.legacy(selfEncryptionKey: _aesKey)),
      );
      await expectLater(
        escrSigningKeyPair(_Signer(client)),
        throwsA(isA<AtClientException>()),
      );
    });
  });
}
