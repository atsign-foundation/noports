import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
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
    MockAtClient clientFor(String atSign, {RsaKeyPair? keyPair}) {
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
        if (owner == atSign && !(options?.useRemoteAtServer ?? false)) {
          throw KeyNotFoundException(
            'public:publickey$owner does not exist in keystore',
          );
        }
        return AtValue()..value = keyPairs[owner]!.atPublicKey.publicKey;
      });
      return client;
    }

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
        throwsA(isA<AtSigningVerificationException>()),
      );
    });
  });
}
