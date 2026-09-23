import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops_ffi.dart';
import 'package:at_utils/at_logger.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srv/aes_ctr_transformer.dart';
import 'package:noports_core/src/srv/srv_impl.dart' show setAesCtrTransformer;
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

class _MockSocket extends Mock implements Socket {}

/// The keystream `srv` produced before the at_chops swap. Any transformer that
/// disagrees with this cannot talk to a peer running the old code.
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
  final DartAesCtr algorithm = DartAesCtr.with256bits(
    macAlgorithm: MacAlgorithm.empty,
  );
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

/// Forces the pure-Dart branch on a host that has libcrypto.
AesCtrFfiCipher? _noCipher(AESKey key, InitialisationVector iv) => null;

/// Collects log records instead of printing them.
class _CapturingLoggingHandler implements LoggingHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void call(LogRecord record) => records.add(record);
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

  // Without libcrypto the default factory resolves to pure-Dart, so a test that
  // compares the two branches would compare pure-Dart with itself and pass
  // having asserted nothing. Skip visibly instead of passing vacuously.
  final AesCtrFfiCipher? probe = AtPqc.aesCtrStreamCipher(
    AESKey(aesKey),
    InitialisationVector.fromBase64(iv),
  );
  probe?.dispose();
  final String? needsFfi = probe == null
      ? 'no usable libcrypto on this host: both branches would be pure-Dart'
      : null;

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

  group('createAesCtrTransformer', () {
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
      // start a fresh keystream — sharing one stateful cipher across streams
      // would hand each of them half a keystream. Only the FFI branch holds a
      // cipher to share; the fallback builds a DartAesCtr per invocation and
      // would pass without the bug being possible.
      final DataTransformer transformer = createAesCtrTransformer(aesKey, iv);
      final List<List<int>> chunks = chunksOf(128, 1024);

      expect(
        await _collect(transformer, chunks),
        await _collect(transformer, chunks),
      );
    }, skip: needsFfi);

    test('an abandoned stream is cleaned up', () async {
      // Cancelling mid-tunnel is the common case, and the path on which a
      // native context leaks if the transform does not release it. The
      // fallback has no context to leak.
      final StreamController<List<int>> controller =
          StreamController<List<int>>();
      final StreamSubscription<List<int>> subscription =
          createAesCtrTransformer(aesKey, iv)(controller.stream).listen(null);

      controller.add(Uint8List.fromList(<int>[1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await controller.close();
    }, skip: needsFfi);

    test(
      'a source error ends the stream rather than being forwarded',
      () async {
        // An error does not close a stream. Merely forwarding one leaves the
        // transform running, holding the native context for as long as a source
        // that errors and stays open lives — so what is asserted here is that
        // nothing after the error is transformed, not that the error arrives.
        final StreamController<List<int>> source =
            StreamController<List<int>>();
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
      },
      skip: needsFfi,
    );

    test(
      'rejects a bad key or IV length where the tunnel is configured',
      () async {
        // Eagerly, not on the first byte: a misconfigured tunnel should not look
        // like a mid-stream failure.
        expect(
          () => createAesCtrTransformer(
            base64Encode(List<int>.filled(20, 0)),
            iv,
          ),
          throwsArgumentError,
        );
        expect(
          () => createAesCtrTransformer(
            aesKey,
            base64Encode(List<int>.filled(12, 0)),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'a failed transform tears the stream down instead of throwing again',
      () async {
        final StreamController<List<int>> source =
            StreamController<List<int>>();
        // Hand out a cipher that is already disposed, so the first update throws.
        final Stream<List<int>> out = createAesCtrTransformer(
          aesKey,
          iv,
          cipherFactory: (AESKey k, InitialisationVector v) {
            final AesCtrFfiCipher c = AtPqc.aesCtrStreamCipher(k, v)!;
            c.dispose();
            return c;
          },
        )(source.stream);

        final Future<List<List<int>>> collected = out.toList();
        source.add(Uint8List.fromList(<int>[1, 2, 3]));
        // A second chunk after the failure must not land on a closed controller.
        source.add(Uint8List.fromList(<int>[4, 5, 6]));

        await expectLater(collected, throwsA(isA<StateError>()));
        await source.close();
      },
      skip: needsFfi,
    );
  });

  group('createAesCtrTransformer, pure-Dart fallback', () {
    // The branch a host with no usable libcrypto takes. It is unreachable here
    // by resolution — AtPqc probes once, statically — so the factory seam is
    // what makes it testable at all.
    test('produces the pre-swap keystream', () async {
      final List<List<int>> chunks = chunksOf(64, 4096);
      expect(
        await _collect(
          createAesCtrTransformer(aesKey, iv, cipherFactory: _noCipher),
          chunks,
        ),
        await _legacyTransform(chunks, aesKey, iv),
      );
    });

    test('agrees with the FFI branch, so tunnel ends may differ', () async {
      // The acceptance criterion of issue #2216: an FFI end and a pure-Dart
      // end have to interoperate.
      final List<List<int>> chunks = chunksOf(7, 2048);
      expect(
        await _collect(createAesCtrTransformer(aesKey, iv), chunks),
        await _collect(
          createAesCtrTransformer(aesKey, iv, cipherFactory: _noCipher),
          chunks,
        ),
      );
    }, skip: needsFfi);

    test('accepts the same key lengths as the FFI branch', () async {
      const String key128 = 'AAIEBggKDA4QEhQWGBocHg==';
      const String key192 = 'AAIEBggKDA4QEhQWGBocHiAiJCYoKiwu';
      final List<List<int>> chunks = chunksOf(64, 512);

      for (final String key in <String>[key128, key192, aesKey]) {
        expect(
          await _collect(
            createAesCtrTransformer(key, iv, cipherFactory: _noCipher),
            chunks,
          ),
          await _collect(createAesCtrTransformer(key, iv), chunks),
          reason: '${base64Decode(key).length}-byte key diverged',
        );
      }
    }, skip: needsFfi);
  });

  group('createAesCtrChunkTransformer', () {
    test('matches createAesCtrTransformer at the same keystream position, at '
        'any chunk size', () async {
      final List<int> expected = await _legacyTransform(
        chunksOf(1024, 4096),
        aesKey,
        iv,
      );
      for (final int size in <int>[1, 7, 16, 1000, 4096]) {
        final ChunkTransformer transformer = createAesCtrChunkTransformer(
          aesKey,
          iv,
        )!;
        final List<int> actual = <int>[];
        try {
          for (final List<int> chunk in chunksOf(size, 4096)) {
            actual.addAll(transformer.transform(chunk));
          }
        } finally {
          transformer.dispose();
        }
        expect(actual, expected, reason: 'chunk size $size diverged');
      }
    }, skip: needsFfi);

    test('returns null without libcrypto, the same trigger as the '
        "DataTransformer path's pure-Dart fallback", () {
      expect(
        createAesCtrChunkTransformer(aesKey, iv, cipherFactory: _noCipher),
        isNull,
      );
    });

    test('rejects a bad key or IV length where the tunnel is configured', () {
      expect(
        () => createAesCtrChunkTransformer(
          base64Encode(List<int>.filled(20, 0)),
          iv,
        ),
        throwsArgumentError,
      );
      expect(
        () => createAesCtrChunkTransformer(
          aesKey,
          base64Encode(List<int>.filled(12, 0)),
        ),
        throwsArgumentError,
      );
    });

    test('a failed transform disposes the cipher; a later chunk still throws '
        'rather than silently succeeding', () {
      final ChunkTransformer transformer = createAesCtrChunkTransformer(
        aesKey,
        iv,
        cipherFactory: (AESKey k, InitialisationVector v) {
          final AesCtrFfiCipher c = AtPqc.aesCtrStreamCipher(k, v)!;
          c.dispose();
          return c;
        },
      )!;
      expect(
        () => transformer.transform(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<StateError>()),
      );
      expect(
        () => transformer.transform(Uint8List.fromList(<int>[4, 5, 6])),
        throwsA(isA<StateError>()),
      );
    }, skip: needsFfi);

    test('dispose is idempotent', () {
      final ChunkTransformer transformer = createAesCtrChunkTransformer(
        aesKey,
        iv,
      )!;
      transformer.dispose();
      expect(transformer.dispose, returnsNormally);
    }, skip: needsFfi);
  });

  group('setAesCtrTransformer', () {
    // srv_impl.dart wires this into every SocketConnector Side that carries
    // tunnel data. The one thing that must never happen is both fields
    // staying null: that relays this side's data unmodified, with no error
    // anywhere, so these check the actual bytes rather than just which
    // field got set.
    test('prefers the chunk transformer when libcrypto is available, and it '
        'actually encrypts', () {
      final Side side = Side(_MockSocket(), true);
      setAesCtrTransformer(side, aesKey, iv);
      expect(side.chunkTransformer, isNotNull);
      expect(side.transformer, isNull);

      final Uint8List plaintext = Uint8List.fromList(
        utf8.encode('not ciphertext yet'),
      );
      final List<int> ciphertext = side.chunkTransformer!.transform(plaintext);
      expect(
        ciphertext,
        isNot(equals(plaintext)),
        reason: 'a no-op transform would relay this in the clear',
      );
    }, skip: needsFfi);

    test('falls back to the DataTransformer, which actually encrypts, when '
        'the chunk path is unavailable', () async {
      final Side side = Side(_MockSocket(), true);
      setAesCtrTransformer(side, aesKey, iv, cipherFactory: _noCipher);
      expect(side.chunkTransformer, isNull);
      expect(side.transformer, isNotNull);

      final Uint8List plaintext = Uint8List.fromList(
        utf8.encode('not ciphertext yet'),
      );
      final List<int> ciphertext = await _collect(
        side.transformer!,
        <List<int>>[plaintext],
      );
      expect(
        ciphertext,
        isNot(equals(plaintext)),
        reason:
            'a side with neither transformer set relays plaintext '
            'with no error anywhere — the fallback must actually encrypt',
      );
    });
  });

  group('cipher path logging', () {
    late _CapturingLoggingHandler handler;
    late List<LogRecord> records;
    late LoggingHandler previousHandler;
    late String previousRootLevel;

    setUp(() {
      handler = _CapturingLoggingHandler();
      records = handler.records;
      previousHandler = AtSignLogger.defaultLoggingHandler;
      previousRootLevel = AtSignLogger.root_level;
      AtSignLogger.defaultLoggingHandler = handler;
      AtSignLogger.root_level = 'info';
      resetAesCtrCipherPathLog();
    });

    // Both of these are process-global: other test files set root_level and
    // assert on it, so leaving either changed leaks across the suite.
    tearDown(() {
      AtSignLogger.defaultLoggingHandler = previousHandler;
      AtSignLogger.root_level = previousRootLevel;
      resetAesCtrCipherPathLog();
    });

    test(
      'the pure-Dart fallback warns, naming libcrypto and the cost',
      () async {
        // The whole point: an operator seeing only degraded throughput has
        // nothing to go on unless this line exists.
        createAesCtrChunkTransformer(aesKey, iv, cipherFactory: _noCipher);

        expect(records, hasLength(1));
        expect(records.single.level, Level.WARNING);
        expect(records.single.message.toLowerCase(), contains('libcrypto'));
        expect(
          records.single.message.toLowerCase(),
          contains('pure-dart'),
          reason: 'the line has to name the backend that was actually used',
        );
      },
    );

    test('the FFI path logs at info, not as a warning', () {
      createAesCtrChunkTransformer(aesKey, iv);

      expect(records, hasLength(1));
      expect(records.single.level, Level.INFO);
      expect(records.single.message.toLowerCase(), contains('ffi'));
    }, skip: needsFfi);

    test('it logs once per process, not once per connection', () async {
      // srv in -multi mode resolves a pair of transformers per connection.
      // libcrypto cannot appear or vanish mid-process, so repeating this
      // would be noise that buries the line it matters on.
      for (int i = 0; i < 5; i++) {
        createAesCtrChunkTransformer(aesKey, iv, cipherFactory: _noCipher);
      }

      expect(records, hasLength(1));
    });

    test('the DataTransformer path logs too, at stream time', () async {
      // createAesCtrTransformer resolves its cipher inside the returned
      // closure, so building the transformer alone must not be what logs —
      // otherwise the control-channel and inline paths stay silent.
      final DataTransformer transformer = createAesCtrTransformer(
        aesKey,
        iv,
        cipherFactory: _noCipher,
      );
      expect(
        records,
        isEmpty,
        reason: 'nothing is resolved until a stream runs',
      );

      await _collect(transformer, <List<int>>[
        Uint8List.fromList(<int>[1, 2, 3]),
      ]);

      expect(records, hasLength(1));
      expect(records.single.level, Level.WARNING);
    });
  });
}
