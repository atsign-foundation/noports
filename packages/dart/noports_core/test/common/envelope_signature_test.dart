import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  group('Given a client or daemon running as @a', () {
    final keyPairs = {
      '@a': RsaKeyPair.generate(),
      '@b': RsaKeyPair.generate(),
    };

    setUpAll(() => registerFallbackValue(AtKey()));

    /// A client for [atSign] holding [keyPair] (by default its own) as its
    /// encryption key pair, whose public-key lookups behave as at_client's
    /// do: its own atSign's key is found only on its atServer, not in local
    /// storage.
    MockAtClient clientFor(
      String atSign, {
      RsaKeyPair? keyPair,
      Map<String, String> published = const {},
      Map<String, String> fetchFails = const {},
    }) {
      final keys = keyPair ?? keyPairs[atSign]!;
      final client = MockAtClient();
      when(() => client.getCurrentAtSign()).thenReturn(atSign);
      when(() => client.atKeysIo).thenReturn(
        InMemoryAtKeysIo.holding(
          atSign,
          AtKeys()
            // ignore: deprecated_member_use
            ..defaultEncryptionPublicKey =
                AtBytes.fromString(keys.atPublicKey.publicKey)
            // ignore: deprecated_member_use
            ..defaultEncryptionPrivateKey =
                AtBytes.fromString(keys.atPrivateKey.privateKey),
        ),
      );
      when(
        () => client.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as AtKey;
        final options = invocation.namedArguments[#getRequestOptions]
            as GetRequestOptions?;
        final owner = key.sharedBy!;
        if (fetchFails[owner] case final message?) {
          throw AtClientException.message(message);
        }
        if (owner == atSign && !(options?.useRemoteAtServer ?? false)) {
          throw KeyNotFoundException(
            'public:publickey$owner does not exist in keystore',
          );
        }
        return AtValue()
          ..value = published[owner] ?? keyPairs[owner]!.atPublicKey.publicKey;
      });
      return client;
    }

    /// A refusal that names [atSign] and does not contain [quoted].
    Matcher refusalNaming(String atSign, {required String without}) => throwsA(
          isA<AtSigningVerificationException>()
              .having((e) => e.toString(), 'message', contains(atSign))
              .having(
                (e) => e.toString(),
                'message',
                isNot(contains(without)),
              ),
        );

    /// [signer]'s envelope as it arrives over the wire.
    Future<Map> envelopeFrom(MockAtClient signer) async => jsonDecode(
          jsonEncode(await signAndWrap(signer, {'sessionId': 'the-session'})),
        );

    test(
        'when it verifies an envelope signed by @a itself, then it checks the'
        " signature against @a's public key fetched from its atServer, and the"
        ' check passes', () async {
      final a = clientFor('@a');

      await verifyEnvelopeSignature(
        a,
        '@a',
        AtSignLogger('test'),
        await envelopeFrom(a),
      );
    });

    test(
        'when it verifies an envelope signed by another atSign, then it checks'
        " against that atSign's public key from the atServer, as now",
        () async {
      await verifyEnvelopeSignature(
        clientFor('@a'),
        '@b',
        AtSignLogger('test'),
        await envelopeFrom(clientFor('@b')),
      );
    });

    test(
        'when an envelope claims to come from @a but was signed with a'
        ' different key, then the check fails', () async {
      final other = clientFor('@a', keyPair: RsaKeyPair.generate());

      await expectLater(
        verifyEnvelopeSignature(
          clientFor('@a'),
          '@a',
          AtSignLogger('test'),
          await envelopeFrom(other),
        ),
        throwsA(
          isA<AtSigningVerificationException>()
              .having((e) => e.toString(), 'message', contains('@a'))
              .having(
                (e) => e.toString(),
                'message',
                isNot(contains(keyPairs['@a']!.atPublicKey.publicKey)),
              ),
        ),
      );
    });

    test(
        "when @a's published public key is not a key, then the check fails,"
        ' and the refusal names @a without quoting what @a published',
        () async {
      const published = 'not-a-key\nnext-line\u2028';
      final a = clientFor('@a', published: {'@a': published});

      await expectLater(
        verifyEnvelopeSignature(
          a,
          '@a',
          AtSignLogger('test'),
          await envelopeFrom(clientFor('@a')),
        ),
        refusalNaming('@a', without: 'not-a-key'),
      );
    });

    test(
        "when @a's published public key is base64 but not a key, then the"
        ' check fails, and the refusal names @a without quoting it', () async {
      final published = base64Encode(utf8.encode('not-a-key'));
      final a = clientFor('@a', published: {'@a': published});

      await expectLater(
        verifyEnvelopeSignature(
          a,
          '@a',
          AtSignLogger('test'),
          await envelopeFrom(clientFor('@a')),
        ),
        refusalNaming('@a', without: published),
      );
    });

    test(
        'when an envelope names a hashingAlgo that is not one, then the check'
        ' fails, and the refusal names @a without quoting the name', () async {
      final envelope = await envelopeFrom(clientFor('@a'));
      envelope['hashingAlgo'] = 'not-an-algo\nnext-line\u2028';

      await expectLater(
        verifyEnvelopeSignature(
          clientFor('@b'),
          '@a',
          AtSignLogger('test'),
          envelope,
        ),
        refusalNaming('@a', without: 'not-an-algo'),
      );
    });

    test(
        'when an envelope names a signingAlgo that is not one, then the check'
        ' fails, and the refusal names @a without quoting the name', () async {
      final envelope = await envelopeFrom(clientFor('@a'));
      envelope['signingAlgo'] = 'not-an-algo\nnext-line\u2028';

      await expectLater(
        verifyEnvelopeSignature(
          clientFor('@b'),
          '@a',
          AtSignLogger('test'),
          envelope,
        ),
        refusalNaming('@a', without: 'not-an-algo'),
      );
    });

    test(
        'when an envelope names a signingAlgo other than rsa2048, then the'
        ' check fails, and the refusal names @a without quoting the name',
        () async {
      final envelope = await envelopeFrom(clientFor('@a'));
      envelope['signingAlgo'] = SigningAlgoType.rsa4096.name;

      await expectLater(
        verifyEnvelopeSignature(
          clientFor('@b'),
          '@a',
          AtSignLogger('test'),
          envelope,
        ),
        refusalNaming('@a', without: SigningAlgoType.rsa4096.name),
      );
    });

    test(
        "when @a's public key cannot be fetched, then the check fails, and the"
        " refusal names @a without quoting the atServer's error", () async {
      final b = clientFor(
        '@b',
        fetchFails: {'@a': 'from-the-atserver\nnext-line\u2028'},
      );

      await expectLater(
        verifyEnvelopeSignature(
          b,
          '@a',
          AtSignLogger('test'),
          await envelopeFrom(clientFor('@a')),
        ),
        refusalNaming('@a', without: 'from-the-atserver'),
      );
    });
  });
}
