import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:at_chops/at_chops_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';

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
