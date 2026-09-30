import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:mutex/mutex.dart';
import 'package:noports_core/src/common/session_crypto.dart';

/// Clients which are authenticating to a relay may use a [RelayAuthenticator]
/// to do so. Responsibility of a [RelayAuthenticator] is typically to
/// - wait to receive some sort of challenge from the relay
/// - send a response back to the relay based on that challenge (typically
///   a signed payload)
/// - wait for confirmation from the relay
abstract interface class RelayAuthenticator {
  /// The function which will do whichever flavour of relay authentication
  /// that is required.
  ///
  /// Returns a stream which Srv's will listen to rather than listening
  /// to the socket directly.
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket);

  /// Map of things to place in the environment when executing the srv
  /// in a separate process
  Map<String, String> get envMap;

  /// Command-line args when executing the srv in a separate process
  List<String> get rvArgs;
}

class RelayAuthenticatorLegacy implements RelayAuthenticator {
  final String authString;

  RelayAuthenticatorLegacy(this.authString);

  /// Map of things to place in the environment when executing the srv
  /// in a separate process
  /// - RV_AUTH: [authString] - sent to relay for legacy (v0) auth
  @override
  Map<String, String> get envMap => {'RV_AUTH': authString};

  @override
  List<String> get rvArgs => ['--rv-auth'];

  /// Legacy authentication just writes the string it's been provided
  /// and returns. Since it doesn't need to listen to the socket
  /// it just returns the socket for the application code to listen to.
  @override
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket) async {
    socket.writeln(authString);
    return (true, socket);
  }
}

/// The keypair a [RelayAuthenticatorESCR] signs with: [signer]'s APKAM
/// authentication keypair, which is what its `_apsk` record advertises while
/// the enrollment holds no signing keys of its own.
///
/// Throws unless that keypair is a 2048-bit RSA key, the only kind srvd
/// verifies, and while the enrollment holds signing keys of its own, since
/// its `_apsk` record then no longer advertises the authentication key.
Future<({String publicKey, String privateKey})> escrSigningKeyPair(
  ApkamSigning signer,
) async {
  if ((await signer.heldSigningKeys).isNotEmpty) {
    throw AtClientException.message(
      'Enrollment ${signer.enrollmentId} holds signing keys of its own, so'
      ' its _apsk record no longer advertises the authentication key that'
      ' relay authentication signs with',
    );
  }
  final key = await signer.authenticationSigningKey;
  if (key == null) {
    throw AtClientException.message(
      'Enrollment ${signer.enrollmentId} holds no APKAM keypair to sign'
      ' relay authentication with',
    );
  }
  if (key.algorithm != SigningAlgoType.rsa2048) {
    throw AtClientException.message(
      'Enrollment ${signer.enrollmentId} authenticates with'
      ' ${key.algorithm.name}; relay authentication needs rsa2048',
    );
  }
  try {
    rsaSignString('', privateKey: key.privateKey);
  } on AtSigningException catch (e) {
    throw AtClientException.message(
      'Enrollment ${signer.enrollmentId} authenticates with a key relay'
      ' authentication cannot sign with: ${e.message}',
    );
  }
  return (publicKey: key.publicKey, privateKey: key.privateKey);
}

/// Authenticate to relay with Encrypted Signed Challenge response
///
/// - listens to socket
/// - waits for challenge (base64 terminated by newline)
/// - constructs challenge response as
///   `${sessionId}:${auth-payload-as-base64}\n`, where
///   - `auth-payload-as-base64` is base64-encoding of
///     `{'iv':'some_iv','e':'encrypted-payload-as-base64'}`
///   - `encrypted-payload-as-base64` is base64-encoding of the encrypted
///     payload, encrypted using the session AES key and the `iv` from above
///   - the actual payload is
///     ```
///     {
///       'p':{'sid':'session-id','c':'challenge','side':'<a|b>'},
///       's':'signature of json string encoding of p
///       'ha':'hashingAlgo',
///       'sa':'signingAlgo',
///       'sk':'public:some_key.some.namespace@atSign'
///     }
///     ```
///     where `s` is signed by some private signing key, and `sk` is the
///     Atsign Protocol URI of the corresponding public key.
/// - sends challenge response `${sessionId}:${auth-payload-as-base64}\n`
/// - waits for confirmation from relay
///   - `ok` is good
///   - anything else is bad
///
class RelayAuthenticatorESCR implements RelayAuthenticator {
  final String sessionId;
  final String relayAuthAesKey;
  final String publicSigningKeyUri;
  final String publicSigningKey;
  final String privateSigningKey;

  /// `true` for client (npt, sshnp, ...) connections
  /// `false` for daemon connections
  final bool isSideA;

  RelayAuthenticatorESCR({
    required this.sessionId,
    required this.relayAuthAesKey,
    required this.publicSigningKeyUri,
    required this.publicSigningKey,
    required this.privateSigningKey,
    required this.isSideA,
  });

  /// Map of things to place in the environment when executing the srv
  /// in a separate process
  /// - sessionId - RV_SESSION_ID - required in the auth message
  /// - relayAuthAesKey - RV_AUTH_AES_KEY - to encrypt the auth envelope
  /// - publicSigningKeyUri - RV_PUB_KEY_URI - used by verifier to fetch the
  ///   publicSigningKey
  /// - privateSigningKey - RV_SIGNING_KEY used here to sign the
  ///   actual payload within the auth envelope
  @override
  Map<String, String> get envMap => {
    'REMOTE_AUTH_ESCR_SESSION_ID': sessionId,
    'REMOTE_AUTH_ESCR_AES_KEY': relayAuthAesKey,
    'REMOTE_AUTH_ESCR_PUB_KEY_URI': publicSigningKeyUri,
    'REMOTE_AUTH_ESCR_SIGNING_PUBKEY': publicSigningKey,
    'REMOTE_AUTH_ESCR_SIGNING_PRIVKEY': privateSigningKey,
    'REMOTE_AUTH_ESCR_IS_SIDE_A': isSideA.toString(),
  };

  @override
  List<String> get rvArgs => ['-a', 'escr'];

  @override
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket) {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool receivedChallenge = false;
    bool authenticated = false;
    // Forward pause/resume to the socket subscription: when the consumer of
    // sc.stream applies backpressure it must reach the socket and close the
    // TCP window, rather than buffering without bound in this controller.
    late final StreamSubscription<Uint8List> subscription;
    StreamController<Uint8List> sc = StreamController(
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
    );
    List<int> buffer = [];

    Mutex listenMutex = Mutex();

    subscription = socket.listen(
      (Uint8List data) async {
        // Fast path: safe only because no `await` separates the residual
        // flush below from `authenticated` flipping to true.
        if (authenticated) {
          sc.add(data);
          return;
        }
        await listenMutex.acquire();
        try {
          if (authenticated) {
            sc.add(data);
          } else {
            // TODO maximum buffer size check to prevent dos attacks
            // TODO unit test for same
            buffer.addAll(data);
            if (buffer.contains(10)) {
              if (receivedChallenge) {
                List<int> received = buffer.sublist(0, buffer.indexOf(10));
                buffer.removeRange(0, buffer.indexOf(10) + 1);

                // "ok" - great. Anything else - error.
                try {
                  /// We've got the verification result from the relay
                  final verifyResult = String.fromCharCodes(received);

                  if (verifyResult == 'ok') {
                    if (buffer.isNotEmpty) {
                      sc.add(Uint8List.fromList(buffer));
                    }

                    authenticated = true;

                    completer.complete((true, sc.stream));
                  } else {
                    if (!completer.isCompleted) {
                      completer.completeError(
                        UnAuthenticatedException(verifyResult),
                      );
                    }
                  }
                } catch (e) {
                  if (!completer.isCompleted) {
                    completer.completeError(
                      'Error during relay authentication: $e',
                    );
                  }
                }
              } else {
                List<int> received = buffer.sublist(0, buffer.indexOf(10));
                buffer.removeRange(0, buffer.indexOf(10) + 1);

                try {
                  /// We've got the `$challenge\n` from relay
                  final challenge = String.fromCharCodes(received);

                  receivedChallenge = true;

                  socket.writeln(await responseToChallenge(challenge));
                  await socket.flush();
                } catch (e) {
                  completer.completeError(
                    'Error during relay authentication: $e',
                  );
                }
              }
            }
          }
        } finally {
          listenMutex.release();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        sc.addError(error);

        sc.close();
      },
      onDone: () => sc.close(),
    );

    return completer.future;
  }

  Future<String> responseToChallenge(String challenge) async {
    /// Construct response payload
    Map envelope = {
      'p': {'sid': sessionId, 'c': challenge, 'side': (isSideA ? 'a' : 'b')},
    };
    envelope['s'] = rsaSignString(
      jsonEncode(envelope['p']),
      privateKey: privateSigningKey,
    );
    envelope['ha'] = HashingAlgoType.sha256.name;
    envelope['sa'] = SigningAlgoType.rsa2048.name;
    envelope['sk'] = publicSigningKeyUri;

    String envelope64 = base64Encode(jsonEncode(envelope).codeUnits);

    /// Encrypt the response payload
    final InitialisationVector iv = generateIv();
    final String envelopeEncrypted64 = await aesEncryptString(
      envelope64,
      key: relayAuthAesKey,
      iv: iv,
    );

    String authPayload64 = base64Encode(
      jsonEncode({
        'iv': base64Encode(iv.ivBytes),
        'e': envelopeEncrypted64,
      }).codeUnits,
    );

    return '$sessionId:$authPayload64';
  }
}
