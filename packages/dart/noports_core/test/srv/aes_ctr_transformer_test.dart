import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:noports_core/src/srv/aes_ctr_transformer.dart';
import 'package:openssl3/evp.dart' as ossl;
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

/// The keystream `srv` produced before the swap to openssl3. Any transformer
/// that disagrees with this cannot talk to a peer running the old code —
/// whether that peer is pre-#2904 `DartAesCtr` or the at_chops FFI cipher,
/// which is pinned against the same keystream in at_chops' own tests.
///
/// [decrypt] selects which half of the old code: `srv` encrypted with
/// `encryptStream` and decrypted with `decryptStream`, and both halves are on
/// the wire, so both are pinned here.
Future<List<int>> _legacyTransform(
  List<List<int>> chunks,
  String aesKeyBase64,
  String ivBase64, {
  bool decrypt = false,
}) async {
  final int keyLength = base64Decode(aesKeyBase64).length;
  final DartAesCtr algorithm = switch (keyLength) {
    16 => DartAesCtr.with128bits(macAlgorithm: MacAlgorithm.empty),
    24 => DartAesCtr.with192bits(macAlgorithm: MacAlgorithm.empty),
    _ => DartAesCtr.with256bits(macAlgorithm: MacAlgorithm.empty),
  };
  final SecretKey key = SecretKey(base64Decode(aesKeyBase64));
  final List<int> nonce = base64Decode(ivBase64);
  final Stream<List<int>> input = Stream<List<int>>.fromIterable(chunks);
  final Stream<List<int>> out = decrypt
      ? algorithm.decryptStream(
          input,
          secretKey: key,
          nonce: nonce,
          mac: Mac.empty,
        )
      : algorithm.encryptStream(
          input,
          secretKey: key,
          nonce: nonce,
          onMac: (Mac mac) {},
        );
  return <int>[for (final List<int> chunk in await out.toList()) ...chunk];
}

Future<List<int>> _collect(
  DataTransformer transformer,
  List<List<int>> chunks,
) async {
  final Stream<List<int>> out = transformer(
    Stream<List<int>>.fromIterable(chunks),
  );
  return <int>[for (final List<int> chunk in await out.toList()) ...chunk];
}

void main() {
  const String aesKey = 'AAcOFRwjKjE4P0ZNVFtiaXB3foWMk5qhqK+2vcTL0tk=';
  const String iv = 'AAECAwQFBgcICQoLDA0ODw==';

  List<List<int>> chunksOf(int size, int total) {
    final List<List<int>> chunks = <List<int>>[];
    for (int i = 0; i < total; i += size) {
      final int end = i + size > total ? total : i + size;
      chunks.add(
        Uint8List.fromList(<int>[for (int j = i; j < end; j++) j & 0xff]),
      );
    }
    return chunks;
  }

  group('createAesCtrTransformer (openssl3)', () {
    test('matches the pre-swap DartAesCtr keystream', () async {
      final List<List<int>> chunks = chunksOf(64, 4096);
      expect(
        await _collect(createAesCtrTransformer(aesKey, iv), chunks),
        await _legacyTransform(chunks, aesKey, iv),
        reason: 'a peer on the old code could not decrypt this tunnel',
      );
    });

    test('matches the pre-swap DartAesCtr decrypt direction', () async {
      // srv ran decryptStream on half of every tunnel. CTR makes the two
      // directions the same transform, but decryptStream is its own code path
      // in package:cryptography — pin it rather than reason about it.
      final List<List<int>> chunks = chunksOf(64, 4096);
      expect(
        await _legacyTransform(chunks, aesKey, iv, decrypt: true),
        await _legacyTransform(chunks, aesKey, iv),
        reason: 'the old decrypter and encrypter must agree byte for byte',
      );
      expect(
        await _collect(createAesCtrTransformer(aesKey, iv), chunks),
        await _legacyTransform(chunks, aesKey, iv, decrypt: true),
      );
    });

    test('matches the pre-swap keystream for 128- and 192-bit keys', () async {
      const String key128 = 'AAIEBggKDA4QEhQWGBocHg==';
      const String key192 = 'AAIEBggKDA4QEhQWGBocHiAiJCYoKiwu';
      final List<List<int>> chunks = chunksOf(64, 512);

      for (final String key in <String>[key128, key192, aesKey]) {
        expect(
          await _collect(createAesCtrTransformer(key, iv), chunks),
          await _legacyTransform(chunks, key, iv),
          reason: '${base64Decode(key).length}-byte key diverged',
        );
      }
    });

    test('is insensitive to how the socket splits the bytes', () async {
      // The transform sees whatever the socket delivers; a chunk boundary
      // inside an AES block must not disturb the keystream.
      final List<int> expected = await _legacyTransform(
        chunksOf(1024, 4096),
        aesKey,
        iv,
      );
      for (final int size in <int>[1, 7, 16, 1000, 4096]) {
        expect(
          await _collect(
            createAesCtrTransformer(aesKey, iv),
            chunksOf(size, 4096),
          ),
          expected,
          reason: 'chunk size $size diverged',
        );
      }
    });

    test('encrypt then decrypt returns the plaintext', () async {
      final List<List<int>> chunks = chunksOf(256, 2048);
      final List<int> plaintext = <int>[
        for (final List<int> chunk in chunks) ...chunk,
      ];

      final List<int> ciphertext = await _collect(
        createAesCtrTransformer(aesKey, iv),
        chunks,
      );
      final List<int> roundTripped = await _collect(
        createAesCtrTransformer(aesKey, iv),
        <List<int>>[Uint8List.fromList(ciphertext)],
      );

      expect(roundTripped, plaintext);
    });

    test('one transformer serves repeated streams independently', () async {
      // A DataTransformer may be invoked more than once. Each invocation must
      // start a fresh keystream — sharing one stateful CipherStream across
      // streams would hand each of them half a keystream.
      final DataTransformer transformer = createAesCtrTransformer(aesKey, iv);
      final List<List<int>> chunks = chunksOf(128, 1024);

      expect(
        await _collect(transformer, chunks),
        await _collect(transformer, chunks),
      );
    });

    test('an abandoned stream is cleaned up', () async {
      // Cancelling mid-tunnel is the common case, and the path on which a
      // native context leaks if the transform does not release it.
      final StreamController<List<int>> controller =
          StreamController<List<int>>();
      final StreamSubscription<List<int>> subscription =
          createAesCtrTransformer(aesKey, iv)(controller.stream).listen(null);

      controller.add(Uint8List.fromList(<int>[1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await controller.close();
    });

    test('a source error ends the stream rather than being forwarded', () async {
      // An error does not close a stream. Merely forwarding one leaves the
      // transform running, holding the native context for as long as a source
      // that errors and stays open lives — so what is asserted here is that
      // nothing after the error is transformed, not that the error arrives.
      final StreamController<List<int>> source = StreamController<List<int>>();
      final List<List<int>> data = <List<int>>[];
      Object? seen;
      bool closed = false;

      createAesCtrTransformer(aesKey, iv)(source.stream).listen(
        data.add,
        onError: (Object error) => seen = error,
        onDone: () => closed = true,
        cancelOnError: false,
      );

      source
        ..add(Uint8List.fromList(<int>[1, 2, 3]))
        ..addError(StateError('socket died'));
      await Future<void>.delayed(Duration.zero);
      // The source stays open, as a half-broken socket would.
      source.add(Uint8List.fromList(<int>[4, 5, 6]));
      await Future<void>.delayed(Duration.zero);

      expect(data, hasLength(1), reason: 'kept transforming after the error');
      expect(seen, isA<StateError>());
      expect(closed, isTrue, reason: 'an open source held the stream open');
      await source.close();
    });

    test('rejects a bad key or IV length where the tunnel is configured', () {
      // Eagerly, not on the first byte: a misconfigured tunnel should not look
      // like a mid-stream failure.
      expect(
        () => createAesCtrTransformer(base64Encode(List<int>.filled(20, 0)), iv),
        throwsArgumentError,
      );
      expect(
        () => createAesCtrTransformer(
          aesKey,
          base64Encode(List<int>.filled(12, 0)),
        ),
        throwsArgumentError,
      );
    });

    test(
      'a failed transform tears the stream down instead of throwing again',
      () async {
        final StreamController<List<int>> source =
            StreamController<List<int>>();
        // Hand out a cipher stream that is already finished, so the first
        // update throws.
        final Stream<List<int>> out = createAesCtrTransformer(
          aesKey,
          iv,
          cipherStreamFactory: (ossl.Cipher c, Uint8List v) {
            final ossl.CipherStream cs = c.encryptStream(v);
            cs.finish();
            return cs;
          },
        )(source.stream);

        final Future<List<List<int>>> collected = out.toList();
        source.add(Uint8List.fromList(<int>[1, 2, 3]));
        // A second chunk after the failure must not land on a closed controller.
        source.add(Uint8List.fromList(<int>[4, 5, 6]));

        await expectLater(collected, throwsA(isA<StateError>()));
        await source.close();
      },
    );
  });
}
