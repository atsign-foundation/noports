import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:at_chops/at_chops_ffi.dart';
import 'package:at_utils/at_logger.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';

bool _cipherPathLogged = false;

@visibleForTesting
void resetAesCtrCipherPathLog() => _cipherPathLogged = false;

/// Records which AES-CTR backend this process resolved, once.
///
/// The fallback is otherwise invisible: a host with no usable libcrypto still
/// tunnels correctly, just slowly, and since a tunnel runs at the speed of its
/// slowest end one quiet fallback caps a link whose other end is on the FFI
/// path.
///
/// Logging only the first resolution is safe because the answer cannot change
/// within a process: `AtPqc.aesCtrStreamCipher` returns null purely on
/// `_aesCtrSupported`, a `static final` probed once, and a bad key or IV makes
/// `AesCtrFfiCipher.fromLib` throw rather than return null. So a null here
/// means libcrypto, and nothing else.
void _logCipherPath({required bool ffi}) {
  if (_cipherPathLogged) return;
  _cipherPathLogged = true;
  final AtSignLogger logger = AtSignLogger('AesCtrTransformer');
  if (ffi) {
    logger.info('AES-CTR backend: OpenSSL via FFI');
  } else {
    logger.warning(
      'AES-CTR backend: pure-Dart — no usable libcrypto was found. Traffic is '
      'encrypted correctly but far more slowly, and a tunnel runs at the speed '
      'of its slowest end, so this caps the link even if the far end has '
      'libcrypto.',
    );
  }
}

/// Builds the AES-CTR [DataTransformer] pair that carries tunnel traffic.
///
/// CTR encryption and decryption are the same operation, so one function
/// serves both directions — the caller decides which end of the tunnel a
/// transformer is attached to.
///
/// Where libcrypto is available the transform runs through at_chops'
/// OpenSSL-backed [AesCtrFfiCipher] (AES-NI); otherwise it falls back to the
/// pure-Dart [DartAesCtr] this replaced. Both produce the same keystream, so
/// the two ends of a tunnel may resolve differently and still interoperate.
///
/// [aesKeyBase64] must decode to 16, 24 or 32 bytes and [ivBase64] to exactly
/// 16 — both are checked here rather than on the first byte, so a misconfigured
/// tunnel fails where it is set up and not as an error on a stream someone is
/// already reading.
///
/// [cipherFactory] exists so tests can force the pure-Dart branch on a host
/// that has libcrypto; production callers leave it alone.
DataTransformer createAesCtrTransformer(
  String aesKeyBase64,
  String ivBase64, {
  @visibleForTesting
  AesCtrFfiCipher? Function(AESKey, InitialisationVector) cipherFactory =
      AtPqc.aesCtrStreamCipher,
}) {
  final AESKey aesKey = AESKey(aesKeyBase64);
  final InitialisationVector iv = InitialisationVector.fromBase64(ivBase64);
  final int keyLength = base64Decode(aesKeyBase64).length;

  if (keyLength != 16 && keyLength != 24 && keyLength != 32) {
    throw ArgumentError.value(
      keyLength,
      'aesKeyBase64',
      'AES key must decode to 16, 24 or 32 bytes',
    );
  }
  if (iv.ivBytes.length != AesCtrFfiCipher.ivLength) {
    throw ArgumentError.value(
      iv.ivBytes.length,
      'ivBase64',
      'AES-CTR IV must decode to exactly ${AesCtrFfiCipher.ivLength} bytes',
    );
  }

  return (Stream<List<int>> stream) {
    // Constructed per stream, not per call to this function: the cipher holds
    // a keystream position, so two streams sharing one instance would each get
    // half a keystream. A DataTransformer may be invoked more than once.
    final AesCtrFfiCipher? cipher = cipherFactory(aesKey, iv);
    _logCipherPath(ffi: cipher != null);
    if (cipher == null) {
      return _pureDartTransform(stream, aesKeyBase64, ivBase64, keyLength);
    }
    return _ffiTransform(stream, cipher);
  };
}

/// Owns [cipher] for the life of the stream and releases it on every exit —
/// completion, error, and cancellation alike.
///
/// Releasing on time is the whole point of this function, and it is why the
/// subscription is driven by hand rather than with `async*` or `map`:
///
/// - `stream.map(cipher.update)` never disposes at all, leaking one
///   `EVP_CIPHER_CTX` per tunnel.
/// - `async*` with `try`/`finally` around `await for` does dispose, but not
///   when you want: a generator suspended on `await for` does not run its
///   `finally` until the *source* stream closes, so a downstream cancel over a
///   socket that stays open holds the context indefinitely.
///
/// Here `onCancel` disposes immediately. `onPause`/`onResume` forward to the
/// source so backpressure still reaches the socket, and a source error is
/// terminal rather than forwarded — see `terminate` below.
Stream<List<int>> _ffiTransform(
  Stream<List<int>> stream,
  AesCtrFfiCipher cipher,
) {
  StreamSubscription<List<int>>? subscription;
  late final StreamController<List<int>> controller;

  controller = StreamController<List<int>>(
    onListen: () {
      // Every exit but `onDone` runs through here: release the context, drop
      // the source, and report the failure downstream exactly once.
      void terminate(Object error, StackTrace stackTrace) {
        if (controller.isClosed) return;
        cipher.dispose();
        subscription?.cancel();
        controller.addError(error, stackTrace);
        controller.close();
      }

      subscription = stream.listen(
        (List<int> chunk) {
          // A source that keeps delivering after the transform failed would
          // otherwise land on a closed controller.
          if (controller.isClosed) return;
          try {
            controller.add(
              cipher.update(
                chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
              ),
            );
          } catch (error, stackTrace) {
            // The context is unusable once a transform fails; nothing after
            // this chunk would decrypt anyway, so tear the whole thing down.
            terminate(error, stackTrace);
          }
        },
        // A source error ends the tunnel. Errors do not close a stream, so
        // forwarding one and reading on would hold the context for as long as
        // a socket that errors and stays open lives.
        onError: terminate,
        onDone: () {
          cipher.dispose();
          controller.close();
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      cipher.dispose();
      return subscription?.cancel();
    },
  );

  return controller.stream;
}

/// Builds the AES-CTR [ChunkTransformer] that carries tunnel traffic via
/// [AesCtrFfiCipher.updateView]'s zero-copy path, skipping the extra
/// [StreamController] and subscription [createAesCtrTransformer]'s
/// [DataTransformer] needs.
///
/// Returns `null` when libcrypto isn't available — [ChunkTransformer] has no
/// pure-Dart equivalent, so the caller falls back to
/// [createAesCtrTransformer] as a [DataTransformer] on [Side.transformer]
/// instead. [aesKeyBase64]/[ivBase64] are validated exactly as
/// [createAesCtrTransformer] validates them.
ChunkTransformer? createAesCtrChunkTransformer(
  String aesKeyBase64,
  String ivBase64, {
  @visibleForTesting
  AesCtrFfiCipher? Function(AESKey, InitialisationVector) cipherFactory =
      AtPqc.aesCtrStreamCipher,
}) {
  final AESKey aesKey = AESKey(aesKeyBase64);
  final InitialisationVector iv = InitialisationVector.fromBase64(ivBase64);
  final int keyLength = base64Decode(aesKeyBase64).length;

  if (keyLength != 16 && keyLength != 24 && keyLength != 32) {
    throw ArgumentError.value(
      keyLength,
      'aesKeyBase64',
      'AES key must decode to 16, 24 or 32 bytes',
    );
  }
  if (iv.ivBytes.length != AesCtrFfiCipher.ivLength) {
    throw ArgumentError.value(
      iv.ivBytes.length,
      'ivBase64',
      'AES-CTR IV must decode to exactly ${AesCtrFfiCipher.ivLength} bytes',
    );
  }

  final AesCtrFfiCipher? cipher = cipherFactory(aesKey, iv);
  _logCipherPath(ffi: cipher != null);
  if (cipher == null) return null;
  return _AesCtrChunkTransformer(cipher);
}

/// Wraps one [AesCtrFfiCipher] as a [ChunkTransformer]. [transform] returns
/// [AesCtrFfiCipher.updateView]'s view unchanged: [SocketConnector] only
/// ever reads it synchronously before writing it to a socket, which is
/// exactly what [ChunkTransformer.transform] and [AesCtrFfiCipher.updateView]
/// each separately promise is safe.
///
/// A failed [transform] disposes the cipher immediately, mirroring
/// [_ffiTransform]'s terminal-dispose behavior: the context is unusable once
/// one transform fails, so nothing after the failing chunk would decrypt
/// correctly anyway.
class _AesCtrChunkTransformer implements ChunkTransformer {
  _AesCtrChunkTransformer(this._cipher);

  final AesCtrFfiCipher _cipher;
  bool _disposed = false;

  @override
  Uint8List transform(List<int> data) {
    try {
      return _cipher.updateView(
        data is Uint8List ? data : Uint8List.fromList(data),
      );
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cipher.dispose();
  }
}

/// The path taken on a host with no usable libcrypto.
///
/// `encryptStream` serves both directions: CTR is its own inverse, and
/// `DartAesCtr.decryptStream` is verified to emit the same bytes over the same
/// input (`aes_ctr_transformer_test.dart`).
Stream<List<int>> _pureDartTransform(
  Stream<List<int>> stream,
  String aesKeyBase64,
  String ivBase64,
  int keyLength,
) {
  // Keyed to match [AesCtrFfiCipher]'s 16/24/32 contract, so the branch a host
  // happens to take never changes which keys it accepts.
  final DartAesCtr algorithm = switch (keyLength) {
    16 => DartAesCtr.with128bits(macAlgorithm: MacAlgorithm.empty),
    24 => DartAesCtr.with192bits(macAlgorithm: MacAlgorithm.empty),
    _ => DartAesCtr.with256bits(macAlgorithm: MacAlgorithm.empty),
  };
  return algorithm.encryptStream(
    stream,
    secretKey: SecretKey(base64Decode(aesKeyBase64)),
    nonce: base64Decode(ivBase64),
    onMac: (Mac mac) {},
  );
}
