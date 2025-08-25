import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:mutex/mutex.dart';

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
///       'p':{'sid':'session-id','c':'challenge'},
///       's':'signature of json string encoding of p
///       'ha':'hashingAlgo',
///       'sa':'signingAlgo',
///       'sk':'public:some_key.some.namespace@atSign'
///     }
///     ```
///     where `s` is signed by some private signing key, and `sk` is the
///     atProtocol URI of the corresponding public key.
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

  late final AtChops _atChops;

  RelayAuthenticatorESCR({
    required this.sessionId,
    required this.relayAuthAesKey,
    required this.publicSigningKeyUri,
    required this.publicSigningKey,
    required this.privateSigningKey,
    required this.isSideA,
  }) {
    _atChops = AtChopsImpl(
      AtChopsKeys()
        ..atEncryptionKeyPair = AtEncryptionKeyPair.create(
          publicSigningKey,
          privateSigningKey,
        ),
    );
  }

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
    StreamController<Uint8List> sc = StreamController();
    List<int> buffer = [];

    Mutex listenMutex = Mutex();

    socket.listen(
      (Uint8List data) async {
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

                  socket.writeln(responseToChallenge(challenge));
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

  String responseToChallenge(String challenge) {
    /// Construct response payload
    Map envelope = {
      'p': {'sid': sessionId, 'c': challenge, 'side': (isSideA ? 'a' : 'b')},
    };
    final AtSigningInput signingInput = AtSigningInput(
      jsonEncode(envelope['p']),
    )..signingMode = AtSigningMode.data;
    final AtSigningResult sr = _atChops.sign(signingInput);
    final String signature = sr.result.toString();
    envelope['s'] = signature;
    envelope['ha'] = sr.atSigningMetaData.hashingAlgoType!.name;
    envelope['sa'] = sr.atSigningMetaData.signingAlgoType!.name;
    envelope['sk'] = publicSigningKeyUri;

    String envelope64 = base64Encode(jsonEncode(envelope).codeUnits);

    /// Encrypt the response payload
    final InitialisationVector iv = AtChopsUtil.generateRandomIV(16);
    final ea = AESEncryptionAlgo(AESKey(relayAuthAesKey));
    final String envelopeEncrypted64 = _atChops
        .encryptString(
          envelope64,
          EncryptionKeyType.aes256,
          encryptionAlgorithm: ea,
          iv: iv,
        )
        .result;

    String authPayload64 = base64Encode(
      jsonEncode({
        'iv': base64Encode(iv.ivBytes),
        'e': envelopeEncrypted64,
      }).codeUnits,
    );

    return '$sessionId:$authPayload64';
  }
}
