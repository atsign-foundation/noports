import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:openssl3/evp.dart' as ossl;
import 'package:socket_connector/socket_connector.dart';

/// Builds the AES-CTR [DataTransformer] pair that carries tunnel traffic.
///
/// CTR encryption and decryption are the same operation, so one function
/// serves both directions — the caller decides which end of the tunnel a
/// transformer is attached to.
///
/// The transform runs through `package:openssl3` — OpenSSL 3.5 libcrypto
/// bundled with the application as a code asset — so it takes the AES-NI
/// path on every host, with no dependency on a system libcrypto and no
/// pure-Dart fallback branch. The keystream is byte-identical to both the
/// at_chops FFI implementation and the pre-swap `DartAesCtr`, so this end
/// interoperates with peers running either.
///
/// [aesKeyBase64] must decode to 16, 24 or 32 bytes and [ivBase64] to exactly
/// 16 — both are checked here rather than on the first byte, so a misconfigured
/// tunnel fails where it is set up and not as an error on a stream someone is
/// already reading.
///
/// [cipherStreamFactory] exists so tests can inject a broken cipher stream;
/// production callers leave it alone.
DataTransformer createAesCtrTransformer(
  String aesKeyBase64,
  String ivBase64, {
  @visibleForTesting
  ossl.CipherStream Function(ossl.Cipher, Uint8List)? cipherStreamFactory,
}) {
  final Uint8List key = base64Decode(aesKeyBase64);
  final Uint8List iv = base64Decode(ivBase64);

  if (key.length != 16 && key.length != 24 && key.length != 32) {
    throw ArgumentError.value(
      key.length,
      'aesKeyBase64',
      'AES key must decode to 16, 24 or 32 bytes',
    );
  }
  if (iv.length != 16) {
    throw ArgumentError.value(
      iv.length,
      'ivBase64',
      'AES-CTR IV must decode to exactly 16 bytes',
    );
  }

  final ossl.Cipher cipher = ossl.Cipher.aesCtr(key);
  final ossl.CipherStream Function(ossl.Cipher, Uint8List) makeStream =
      cipherStreamFactory ?? (c, v) => c.encryptStream(v);

  return (Stream<List<int>> stream) {
    // Constructed per stream, not per call to this function: the CipherStream
    // holds a keystream position, so two streams sharing one instance would
    // each get half a keystream. A DataTransformer may be invoked more than
    // once.
    return _transform(stream, makeStream(cipher, iv));
  };
}

/// Owns [cipher] for the life of the stream and releases it on every exit —
/// completion, error, and cancellation alike.
///
/// Releasing on time is the whole point of this function, and it is why the
/// subscription is driven by hand rather than with `async*` or `map`:
///
/// - `stream.map(cipher.update)` never disposes at all, leaking one
///   `EVP_CIPHER_CTX` per tunnel (openssl3's [NativeFinalizer] would reclaim
///   it eventually, but eventually is not when a tunnel closes).
/// - `async*` with `try`/`finally` around `await for` does dispose, but not
///   when you want: a generator suspended on `await for` does not run its
///   `finally` until the *source* stream closes, so a downstream cancel over a
///   socket that stays open holds the context indefinitely.
///
/// Here `onCancel` disposes immediately. `onPause`/`onResume` forward to the
/// source so backpressure still reaches the socket, and a source error is
/// terminal rather than forwarded — see `terminate` below.
Stream<List<int>> _transform(
  Stream<List<int>> stream,
  ossl.CipherStream cipher,
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
            controller.add(cipher.update(chunk));
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
