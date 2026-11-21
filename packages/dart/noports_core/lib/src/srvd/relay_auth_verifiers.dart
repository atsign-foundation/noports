import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:mutex/mutex.dart';

import '../../utils.dart';
import '../common/enrollment_signature.dart';
import '../common/session_crypto.dart';

enum RAVEReason {
  jsonDecodeFailed,
  malformedChallengeResponse,
  sessionNotActive,
  dataMismatch,
  decryptionFailed,
  signatureVerificationFailed,
  randomlyInjectedFailure,
}

class RAVE implements Exception {
  final String message;
  final RAVEReason reason;

  RAVE(this.message, this.reason);

  @override
  String toString() {
    return 'RelayAuthVerifierException: ${reason.name} : $message';
  }
}

abstract interface class RelayAuthVerifyHelper {
  Future<String> lookup(String sessionId, String atKey);

  Future<bool> isSessionActive(String sessionId);

  Future<String> getRelayAuthAesKey(String sessionId);
}

abstract interface class RelayAuthVerifier {
  /// The most a client may send before it has authenticated: room for an
  /// ESCR response signed with ML-DSA-65, the largest a relay verifies, which
  /// is 11,270 bytes for an atSign of the protocol's maximum 55 characters.
  static final maxAuthBufferLength = 16384;

  /// The auth verification which is expected
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket);

  /// The atSign connecting. Note that we may not know this until
  /// authentication has succeeded.
  Atsign? get atSign;

  /// The session being connected to. Note that we may not know this until
  /// authentication has succeeded.
  String? get sessionId;

  /// For log messages
  String get tag;
}

/// RelayAuthVerifierESCR where ESCR stands for "Encrypted Signed Challenge-Response"
///
/// Authenticates new socket connection as follows:
/// 1. Send a challenge to the client, terminated with a newline
/// 2. Receive `${sessionId}:${auth-payload-as-base64}\n` from client
/// 3. Verify that `sessionId` is currently active
/// 4. Auth payload is json like this: `{'iv':'dsahjk','e':'ecehwuorhi'}`
/// 5. Fetch session's AES key. Use it and the provided IV to decrypt the auth envelope
/// 6. Expect decrypted auth envelope to look like this:
///   ```
///   {
///     'p':{'sid':'session-id','c':'challenge','side':'<a|b>'},
///     's':'signature of p encoded as string',
///     'ha':'hashingAlgo',
///     'sa':'signingAlgo',
///     'sk':'public:_apsk.<enrollmentId>.a.__e@atSign',
///     'kid':'id of the signing key within sk'
///   }
///   ```
/// 7. Verify that the contents of the payload are as expected (session id, challenge)
/// 8. Fetch the `_apsk` record at `sk`: a bare RSA key, or a JSON
///   advertisement of keys
/// 9. Require `sa` to be the strongest algorithm among the keys it offers for
///   new signatures, take the key `kid` names (or the only one, when there is
///   no `kid`), and verify the signature with it: RSA-2048 over `ha`, or
///   ML-DSA-65
/// 10. If all successful
///   - `socket.writeln('ok');`
///   - complete successfully
class RelayAuthVerifierESCR implements RelayAuthVerifier {
  @override
  Atsign? atSign;

  @override
  String? sessionId;

  @override
  final String tag;

  final RelayAuthVerifyHelper helper;


  /// A fresh, unguessable challenge for this one authentication. It is the sole
  /// replay protection, so it MUST be fresh per connection — which is why this
  /// verifier is single-use ([_consumed]): a new instance (hence a new
  /// challenge) is required for every connection. Reusing one instance across a
  /// session's connections would reissue the same challenge and let a captured
  /// response be replayed onto further connections.
  final String challenge = generateAes256Key();

  /// Set once this verifier has issued its challenge and verified (or attempted
  /// to verify) a response. Guards against instance reuse — see [challenge].
  bool _consumed = false;

  /// If [randomlyFail] > 0 && random.nextInt([randomlyFail]) == 0
  /// then fail the verification
  final int randomlyFail;

  /// If [randomlyAddLatency] > 0 && random.nextInt([randomlyAddLatency]) == 0
  /// then add (100 + random.nextInt(3900))ms delay
  final int randomlyAddLatency;

  late final AtSignLogger logger;

  bool? isSideA;

  /// The `_apsk` record the response was signed with, once it has verified.
  String? signingKeyUri;

  Random random = Random();

  RelayAuthVerifierESCR(
    this.tag,
    this.helper, {
    this.randomlyFail = 0,
    this.randomlyAddLatency = 0,
  }) {
    logger = AtSignLogger(' $runtimeType ($tag) ');
  }

  Future<bool> verifyChallengeResponse(String response) async {
    // Single-use. Verifying a second response on the same instance would mean
    // its challenge is being reused across connections, so refuse it. This also
    // removes what used to be a re-entrance hazard here (shared atSign /
    // sessionId / isSideA fields), since only one response is ever processed.
    if (_consumed) {
      throw StateError(
        'RelayAuthVerifierESCR is single-use: construct a new instance per'
        ' connection so that each gets its own fresh challenge',
      );
    }
    _consumed = true;

    String abbreviated = response;
    if (response.length > 40) {
      abbreviated =
          '${response.substring(0, 40)}'
          '...[${response.length - 40} chars]';
    }

    // Split by ':' - expect two parts - sessionId, encryptedAuthEnvelope64
    List<String> responseParts = response.split(':');
    if (responseParts.length != 2) {
      throw RAVE(
        'Expected <sid>:<payload> but got $abbreviated',
        RAVEReason.malformedChallengeResponse,
      );
    }
    if (!isValidSessionId(responseParts[0])) {
      throw RAVE(
        'The response names a session whose id is not a UUID',
        RAVEReason.malformedChallengeResponse,
      );
    }
    // NOTE: folded, as srvd holds every session id
    sessionId = responseParts[0].toLowerCase();
    String encryptedAuthEnvelope64 = responseParts[1];
    String encryptedAuthEnvelopeJson;
    try {
      encryptedAuthEnvelopeJson = String.fromCharCodes(
        base64Decode(encryptedAuthEnvelope64),
      );
    } catch (err) {
      throw RAVE(
        '${err.runtimeType} while doing'
        ' String.fromCharCodes(base64Decode(encryptedAuthEnvelope64))'
        ' on $abbreviated',
        RAVEReason.malformedChallengeResponse,
      );
    }

    /// 3. Verify that `sessionId` is currently active
    final bool active = await helper.isSessionActive(sessionId!);
    if (!active) {
      throw RAVE(
        'Session $sessionId is not active',
        RAVEReason.sessionNotActive,
      );
    }

    /// 4. Auth payload is json like this: `{'iv':'dsahjk','e':'ecehwuorhi'}`
    final Map encryptedAuthEnvelope;
    try {
      encryptedAuthEnvelope = jsonDecode(encryptedAuthEnvelopeJson);
    } catch (err) {
      throw RAVE(
        'Unable to decode encryptedAuthEnvelopJson'
        ' ($encryptedAuthEnvelopeJson)',
        RAVEReason.jsonDecodeFailed,
      );
    }
    final String iv;
    try {
      iv = encryptedAuthEnvelope['iv'];
    } catch (err) {
      throw RAVE(
        'No iv in encryptedAuthEnvelope',
        RAVEReason.malformedChallengeResponse,
      );
    }
    final String envelopeEncrypted64;
    try {
      envelopeEncrypted64 = encryptedAuthEnvelope['e'];
    } catch (err) {
      throw RAVE(
        'No envelopeEncrypted ("e") in encryptedAuthEnvelope',
        RAVEReason.malformedChallengeResponse,
      );
    }

    /// 5. Use session's AES key and the provided IV to decrypt the auth envelope
    // Fetch the session's AES Key
    String aesKey64 = await helper.getRelayAuthAesKey(sessionId!);

    String envelope64;
    try {
      envelope64 = await aesDecryptString(
        envelopeEncrypted64,
        key: aesKey64,
        iv: InitialisationVector(base64Decode(iv)),
      );
    } catch (err) {
      throw RAVE(
        'Could not decrypt auth envelope: $err',
        RAVEReason.decryptionFailed,
      );
    }
    String envelopeJson = String.fromCharCodes(base64Decode(envelope64));

    /// Expect decrypted auth envelope to look like this:
    ///   ```
    ///   {
    ///     'p':{'sid':'session-id','c':'challenge','side':'<a|b>'},
    ///     's':'signature of p encoded as string',
    ///     'ha':'hashingAlgo',
    ///     'sa':'signingAlgo',
    ///     'sk':'public:_apsk.<enrollmentId>.a.__e@atSign',
    ///     'kid':'id of the signing key within sk'
    ///   }
    ///   ```
    Map envelope = jsonDecode(envelopeJson);

    /// Verify that the contents of the payload are as expected (session id, challenge, side)
    var signedPayload = envelope['p'];
    if (signedPayload == null || signedPayload is! Map) {
      throw RAVE(
        'Decrypted challenge response envelope does not contain signedPayload',
        RAVEReason.malformedChallengeResponse,
      );
    }
    var side = (signedPayload['side'] ?? '').toString().toLowerCase();
    if (side == 'a') {
      isSideA = true;
    } else if (side == 'b') {
      isSideA = false;
    } else {
      throw RAVE(
        'signedPayload side ("${signedPayload['side']}")'
        ' must be either "a" or "b"',
        RAVEReason.malformedChallengeResponse,
      );
    }
    final Object? signedSessionId = signedPayload['sid'];
    if (signedSessionId is! String ||
        signedSessionId.toLowerCase() != sessionId) {
      throw RAVE(
        'signedPayload sessionId does not match expected sessionId'
        ' ($sessionId)',
        RAVEReason.dataMismatch,
      );
    }
    if (signedPayload['c'] != challenge) {
      throw RAVE(
        'signedPayload challenge (${signedPayload['c']})'
        ' does not match challenge issued ($challenge)',
        RAVEReason.dataMismatch,
      );
    }

    /// Fetch the public signing key
    String publicSigningKeyUri = envelope['sk'];
    if (!publicSigningKeyUri
        .substring(0, publicSigningKeyUri.lastIndexOf('@'))
        .endsWith(EnrollmentConstants.perEnrollmentApproved)) {
      throw RAVE(
        'Signing key ($publicSigningKeyUri)'
        ' is not in the per-enrollment data namespace'
        ' (${EnrollmentConstants.perEnrollmentApproved})',
        RAVEReason.signatureVerificationFailed,
      );
    }
    if (!signingKeyUriShape.hasMatch(publicSigningKeyUri)) {
      throw RAVE(
        'Signing key ($publicSigningKeyUri) is not of the form'
        ' public:_apsk.<enrollmentId>'
        '.${EnrollmentConstants.perEnrollmentApproved}@<atSign>',
        RAVEReason.signatureVerificationFailed,
      );
    }
    final writtenAtSign = publicSigningKeyUri.substring(
      publicSigningKeyUri.lastIndexOf('@'),
    );
    final signer = writtenAtSign.toAtsign();
    if (writtenAtSign.toLowerCase() != signer) {
      throw RAVE(
        'Signing key ($publicSigningKeyUri) spells its atSign other than'
        ' as $signer',
        RAVEReason.signatureVerificationFailed,
      );
    }
    atSign = signer;
    final hashingAlgo = HashingAlgoType.values.byName(envelope['ha']);
    final signingAlgo = SigningAlgoType.values.byName(envelope['sa']);
    if (!escrSigningAlgorithms.contains(signingAlgo)) {
      throw RAVE(
        'Unsupported signing algorithm ${signingAlgo.name}',
        RAVEReason.signatureVerificationFailed,
      );
    }

    try {
      await verifyApskSignature(
        uri: publicSigningKeyUri,
        apsk: await helper.lookup(sessionId!, publicSigningKeyUri),
        signed: jsonEncode(signedPayload),
        signature: envelope['s'],
        signingAlgo: signingAlgo,
        hashingAlgo: hashingAlgo,
        kid: switch (envelope['kid']) {
          null => null,
          final String kid => kid,
          final other => throw ApskSignatureException(
              'The signature names key $other, which is not a string',
            ),
        },
      );
    } on ApskSignatureException catch (e) {
      throw RAVE(e.message, RAVEReason.signatureVerificationFailed);
    }

    signingKeyUri = publicSigningKeyUri;
    return true;
  }

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    // Single-use: refuse before reissuing a stale challenge to a new socket.
    if (_consumed) {
      throw StateError(
        'RelayAuthVerifierESCR is single-use: construct a new instance per'
        ' connection so that each gets its own fresh challenge',
      );
    }

    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    // Forward pause/resume to the socket subscription: when the consumer of
    // sc.stream applies backpressure it must reach the socket and close the
    // TCP window, rather than buffering without bound in this controller.
    late final StreamSubscription<Uint8List> subscription;
    StreamController<Uint8List> sc = StreamController(
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
    );
    logger.info('starting listen');
    List<int> buffer = [];

    /// 1. Sends a challenge to the client, terminated with a newline
    socket.writeln(challenge);
    await socket.flush();

    Mutex listenMutex = Mutex();

    void failIfUnauthenticated(String why) {
      if (authenticated || completer.isCompleted) return;
      logger.info(why);
      socket.destroy();
      completer.completeError('Error during socket authentication: $why');
    }

    subscription = socket.listen(
      (Uint8List data) async {
        // Fast path: safe only because no `await` separates `authenticated`
        // flipping to true (below) from the residual flush that follows it.
        if (authenticated) {
          if (!sc.isClosed) {
            try {
              sc.add(data);
            } catch (err) {
              logger.shout('post-verify sc.add failed with $err');
            }
          }
          return;
        }
        await listenMutex.acquire();
        try {
          if (authenticated) {
            if (!sc.isClosed) {
              try {
                sc.add(data);
              } catch (err) {
                logger.shout('post-verify sc.add failed with $err');
              }
            }
          } else {
            if (buffer.length + data.length >
                RelayAuthVerifier.maxAuthBufferLength) {
              throw RAVE(
                'Too much data from client'
                ' (more than ${RelayAuthVerifier.maxAuthBufferLength} bytes)',
                RAVEReason.malformedChallengeResponse,
              );
            }
            buffer.addAll(data);
            if (buffer.contains(10)) {
              logger.finer('original buffer length ${buffer.length}');

              List<int> authBuffer = buffer.sublist(0, buffer.indexOf(10));
              logger.finer('authBuffer length ${authBuffer.length}');

              buffer.removeRange(0, buffer.indexOf(10) + 1);
              logger.finer('remaining buffer length ${buffer.length}');

              /// 2. Receives `${sessionId}:${auth-payload-as-base64}\n` from client
              final response = String.fromCharCodes(authBuffer).trim();
              for (final cu in response.codeUnits) {
                if (isUnprintable(cu)) {
                  throw RAVE(
                    'received unprintable code units',
                    RAVEReason.malformedChallengeResponse,
                  );
                }
              }
              logger.finer('received data: $response');

              bool verified = await verifyChallengeResponse(response);

              if (!verified) {
                throw RAVE(
                  '(but verifyChallengeResponse did not throw an exception)',
                  RAVEReason.signatureVerificationFailed,
                );
              }

              if (randomlyFail > 0 && random.nextInt(randomlyFail) == 0) {
                throw RAVE(
                  'Randomly injected failure',
                  RAVEReason.randomlyInjectedFailure,
                );
              }

              if (randomlyAddLatency > 0 &&
                  random.nextInt(randomlyAddLatency) == 0) {
                final int l = 100 + random.nextInt(3900);
                logger.shout('Injecting random latency of $l ms');
                await Future.delayed(Duration(milliseconds: l));
              }

              logger.info('Verification success');

              /// If all successful
              /// - send 'ok' to client
              /// - return (true, dataStream)
              socket.writeln('ok');
              await socket.flush();

              authenticated = true;
              if (!completer.isCompleted) {
                completer.complete((true, sc.stream));
              } else {
                if (!sc.isClosed) {
                  sc.addError(
                    'Verify succeeded but'
                    ' completer already completed!!!',
                  );
                }
              }

              if (buffer.isNotEmpty) {
                if (!sc.isClosed) {
                  try {
                    sc.add(Uint8List.fromList(buffer));
                  } catch (err) {
                    logger.shout('finishing verify: sc.add failed with $err');
                  }
                }
              }
            }
          }
        } catch (e) {
          logger.shout(
            'verification FAILED with exception :'
            ' $e',
          );

          if (!completer.isCompleted) {
            // TODO Make this a feature flag to see the exception or not
            socket.writeln('Socket auth failed');
            try {
              await socket.flush();
              socket.destroy();
            } catch (_) {
            } finally {
              completer.completeError('Error during socket authentication: $e');
            }
          }
        } finally {
          listenMutex.release();
        }
      },
      // NOTE: end through the mutex, behind a response still being verified.
      onError: (Object error, StackTrace stackTrace) async {
        await listenMutex.acquire();
        try {
          failIfUnauthenticated(
            'the socket failed before it authenticated: $error',
          );
          if (!sc.isClosed) {
            sc.addError(error);
            unawaited(sc.close());
          }
        } finally {
          listenMutex.release();
        }
      },
      onDone: () async {
        await listenMutex.acquire();
        try {
          failIfUnauthenticated('the socket closed before it authenticated');
          if (!sc.isClosed) {
            unawaited(sc.close());
          }
        } finally {
          listenMutex.release();
        }
      },
    );
    return completer.future;
  }
}

///
/// Verifies signature of the data received over the socket using the same signing algorithm used to sign the data
/// See [SigningAlgoType] to know more about supported signing algorithms
/// See [HashingAlgoType] to know more about supported hashing algorithms
///
/// Expects the first message received in JSON format, with the following structure:
/// {
///       "signature":"<base64 encoded signature>",
///       "hashingAlgo":"<algo>",
///       "signingAlgo":"<algo>"
///  }
///
/// also expects signature to be base64 encoded
///
class RelayAuthVerifierLegacy implements RelayAuthVerifier {
  /// Public key of the signing algorithm used to sign the data
  String publicKey;

  /// data that was signed, this is the data that should be matched once the signature is verified
  String dataToVerify;

  /// string generated by rvd which should be included in auth strings from sshnp and sshnpd
  String rvdNonce;

  /// a tag to help decipher logs
  @override
  String tag;

  @override
  final Atsign atSign;

  @override
  final String sessionId;

  late final AtSignLogger logger;

  RelayAuthVerifierLegacy(
    this.publicKey,
    this.dataToVerify,
    this.rvdNonce,
    this.tag,
    this.atSign,
    this.sessionId,
  ) {
    logger = AtSignLogger(' $runtimeType ($tag) ');
  }

  /// Verify a legacy signature envelope [message] (a JSON string).
  ///
  /// We expect the authenticating client to send a JSON message with
  /// this structure:
  /// ```json
  /// {
  /// "signature":"&lt;signature&gt;",
  /// "hashingAlgo":"&lt;algo&gt;",
  /// "signingAlgo":"&lt;algo&gt;",
  /// "payload":&lt;the data which was signed&gt;
  /// }
  /// ```
  /// The signature is verified against [dataToVerify] and, although not
  /// strictly necessary, the rvdNonce is also checked in what the client
  /// sent in the payload. Only rsa2048 signatures are accepted. Throws a
  /// [RAVE] on any failure; completes normally on success.
  ///
  /// [RelayAuthVerifierAuto] calls this once it has detected that a
  /// connecting side is using legacy auth.
  Future<void> verifyEnvelope(String message) async {
    logger.finer('$tag received data: $message');
    final envelope = jsonDecode(message);
    logger.finer('$tag decoded JSON message OK');

    final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
    final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);

    final payload = envelope['payload'];
    if (payload == null || payload is! Map) {
      throw RAVE(
        'Received an auth signature which does not include the payload',
        RAVEReason.malformedChallengeResponse,
      );
    }
    if (payload['rvdNonce'] != rvdNonce) {
      throw RAVE(
        'Received rvdNonce which does not match what is expected',
        RAVEReason.dataMismatch,
      );
    }

    final bool verified =
        signingAlgo == SigningAlgoType.rsa2048 &&
        await rsaVerifyString(
          dataToVerify,
          signature: envelope['signature'],
          publicKey: publicKey,
          hashing: hashingAlgo,
        );
    if (!verified) {
      logger.shout('$tag : verification FAILURE');
      throw RAVE(
        'Signature verification failed. Signatures did not match.',
        RAVEReason.signatureVerificationFailed,
      );
    }
    logger.info('$tag : verification SUCCESS');
  }

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    // Forward pause/resume to the socket subscription: when the consumer of
    // sc.stream applies backpressure it must reach the socket and close the
    // TCP window, rather than buffering without bound in this controller.
    late final StreamSubscription<Uint8List> subscription;
    StreamController<Uint8List> sc = StreamController(
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
    );
    logger.info('SignatureAuthVerifier for $tag: starting listen');
    List<int> buffer = [];

    void failIfUnauthenticated(String why) {
      if (authenticated || completer.isCompleted) return;
      logger.info('$tag : $why');
      socket.destroy();
      completer.completeError('Error during socket authentication: $why');
    }

    subscription = socket.listen(
      (Uint8List data) async {
        if (authenticated) {
          if (!sc.isClosed) {
            try {
              sc.add(data);
            } catch (err) {
              logger.shout('post-verify sc.add failed with $err');
            }
          }
        } else {
          // NOTE: verification awaits, so later chunks and the close must wait
          // for this one
          subscription.pause();
          try {
            if (buffer.length + data.length >
                RelayAuthVerifier.maxAuthBufferLength) {
              throw RAVE(
                'Too much data from client'
                ' (more than ${RelayAuthVerifier.maxAuthBufferLength} bytes)',
                RAVEReason.malformedChallengeResponse,
              );
            }
            buffer.addAll(data);
            if (buffer.contains(10)) {
              List<int> authBuffer = buffer.sublist(0, buffer.indexOf(10));
              buffer.removeRange(0, buffer.indexOf(10) + 1);

              final String message;
              try {
                message = String.fromCharCodes(authBuffer);
              } catch (e) {
                throw RAVE(
                  'Caught ${e.runtimeType}'
                  ' while creating String from received authBuffer',
                  RAVEReason.malformedChallengeResponse,
                );
              }

              await verifyEnvelope(message);

              authenticated = true;
              if (!completer.isCompleted) {
                completer.complete((true, sc.stream));
              } else {
                if (!sc.isClosed) {
                  sc.addError(
                    'Verify succeeded but'
                    ' completer already completed!!!',
                  );
                }
              }

              if (buffer.isNotEmpty) {
                if (!sc.isClosed) {
                  try {
                    sc.add(Uint8List.fromList(buffer));
                  } catch (err) {
                    logger.shout('finishing verify: sc.add failed with $err');
                  }
                }
              }
            }
          } catch (e) {
            logger.shout(
              '$tag :'
              ' verification FAILED with exception :'
              ' $e',
            );

            if (!completer.isCompleted) {
              completer.completeError('Error during socket authentication: $e');
            }
          } finally {
            subscription.resume();
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        failIfUnauthenticated(
          'the socket failed before it authenticated: $error',
        );
        if (!sc.isClosed) {
          sc.addError(error);
          sc.close();
        }
      },
      onDone: () {
        failIfUnauthenticated('the socket closed before it authenticated');
        if (!sc.isClosed) {
          sc.close();
        }
      },
    );
    return completer.future;
  }
}

/// A [RelayAuthVerifier] for one side of a two-port session, which verifies
/// each socket by the relay auth mode the session's client gave that side:
/// ESCR ([RelayAuthVerifierESCR]) or legacy ([RelayAuthVerifierLegacy]).
///
/// When the side's mode is known ([knownMode], or [setKnownMode] before the
/// socket connects), a socket is verified by it from the moment it connects:
/// an ESCR socket is challenged at once, and a legacy socket is sent nothing
/// and must send its signed envelope. Otherwise the socket waits, sent
/// nothing, until the client names the side's mode ([setKnownMode]) or the
/// socket's first byte is `{`, which is legacy; any other first byte is
/// refused. How long a socket stays silent never decides its mode: one that
/// nobody speaks for is closed by the connector's authentication limit.
///
/// A socket keeps the mode it has once it has one; [setKnownMode] reaches
/// every socket still waiting.
///
/// An ESCR response is accepted only when it is for this verifier's session
/// and side, and is signed by [expectedAtSign].
class RelayAuthVerifierAuto implements RelayAuthVerifier {
  @override
  final String tag;

  final RelayAuthVerifyHelper helper;

  /// The atSign expected on this side of the tunnel. On the two-port relay path
  /// the side (A/B) is known from which port the socket arrived on, so we know
  /// the atSign up front; it is used for the legacy public-key lookup.
  final String expectedAtSign;

  final String _sessionId;

  /// Whether this verifier guards side A (the client's side) of the session.
  final bool isSideA;

  /// Legacy branch: the data whose signature is verified — the JSON encoding of
  /// `{sessionId, clientNonce, rvdNonce}`.
  final String dataToVerify;

  /// Legacy branch: the rvdNonce which must appear in the signed payload.
  final String rvdNonce;

  /// Legacy branch: a pre-supplied public key for [expectedAtSign]. If null it
  /// is looked up lazily (and only if the socket turns out to be legacy).
  final String? publicKey;

  /// Called with the `_apsk` record an ESCR socket on this side was signed
  /// with, once the socket has been accepted.
  final void Function(String signingKeyUri)? onEscrVerified;

  late final AtSignLogger logger;

  /// The mode this side's sockets use, or null until the client names it.
  RelayAuthMode? _knownMode;

  /// Gives each socket of this side still waiting for a mode its mode.
  final Set<Future<void> Function(RelayAuthMode)> _waiting = {};

  RelayAuthVerifierAuto(
    this.tag,
    this.helper, {
    required String atSign,
    required String sessionId,
    required this.isSideA,
    required this.dataToVerify,
    required this.rvdNonce,
    this.publicKey,
    this.onEscrVerified,
    RelayAuthMode? knownMode,
  }) : expectedAtSign = atSign,
       _sessionId = sessionId {
    logger = AtSignLogger(' $runtimeType ($tag) ');
    _knownMode = knownMode;
  }

  /// The mode this side's sockets use, or null until the client names it.
  @visibleForTesting
  RelayAuthMode? get knownMode => _knownMode;

  /// How many of this side's sockets are waiting for a mode.
  @visibleForTesting
  int get waitingSockets => _waiting.length;

  /// Gives this side [mode]: every socket still waiting for a mode takes it,
  /// and so does every socket that connects afterwards. A socket that already
  /// has a mode keeps it.
  void setKnownMode(RelayAuthMode mode) {
    _knownMode = mode;
    for (final resolve in _waiting.toList()) {
      unawaited(resolve(mode));
    }
  }

  // On the two-port path the side (and thus atSign) is known from the port the
  // socket arrived on, so we report the expected values directly. These are not
  // consulted by SocketConnector.serverToServer (which uses the returned
  // stream); they exist only to satisfy the RelayAuthVerifier interface.
  @override
  Atsign? get atSign => expectedAtSign.toAtsign();

  @override
  String? get sessionId => _sessionId;

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    // A fresh ESCR verifier per connection: single-use, so each connection gets
    // its own fresh challenge (never reused across the session's connections).
    final RelayAuthVerifierESCR escr = RelayAuthVerifierESCR(tag, helper);

    final completer = Completer<(bool, Stream<Uint8List>?)>();
    // NOTE: pause/resume must reach the socket subscription, or a slow
    // consumer leaves the post-auth bytes buffering here without bound.
    late final StreamSubscription<Uint8List> subscription;
    final sc = StreamController<Uint8List>(
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
    );
    final buffer = <int>[];
    bool authenticated = false;

    // 'waiting' -> 'legacy' | 'escr'. Guarded by [mutex] so the client's word
    // and inbound data cannot race to pick different modes.
    String mode = 'waiting';
    final mutex = Mutex();
    Future<void> Function(RelayAuthMode)? waitingFor;

    void stopWaiting() {
      final Future<void> Function(RelayAuthMode)? w = waitingFor;
      if (w != null) _waiting.remove(w);
      waitingFor = null;
    }

    Future<void> failAuth(Object e) async {
      stopWaiting();
      logger.shout('auto verification FAILED with exception : $e');
      if (!completer.isCompleted) {
        try {
          // NOTE: only a challenged peer reads from the relay; a legacy peer
          // forwards anything written here to its local app.
          if (mode == 'escr') {
            socket.writeln('Socket auth failed');
            await socket.flush();
          }
          socket.destroy();
        } catch (_) {
        } finally {
          completer.completeError('Error during socket authentication: $e');
        }
      }
    }

    void failIfUnauthenticated(String why) {
      if (authenticated || completer.isCompleted) return;
      logger.info(why);
      socket.destroy();
      completer.completeError('Error during socket authentication: $why');
    }

    void completeSuccess() {
      authenticated = true;
      if (!completer.isCompleted) {
        completer.complete((true, sc.stream));
      } else if (!sc.isClosed) {
        sc.addError('Verify succeeded but completer already completed!!!');
      }
      if (buffer.isNotEmpty) {
        if (!sc.isClosed) {
          try {
            sc.add(Uint8List.fromList(buffer));
          } catch (err) {
            logger.shout('finishing verify: sc.add failed with $err');
          }
        }
        buffer.clear();
      }
    }

    Future<void> handleLegacyLine(String message) async {
      final String pk =
          publicKey ??
          await helper.lookup(_sessionId, 'public:publickey$expectedAtSign');
      final legacy = RelayAuthVerifierLegacy(
        pk,
        dataToVerify,
        rvdNonce,
        tag,
        expectedAtSign.toAtsign(),
        _sessionId,
      );
      // Throws on failure. Note: legacy sends nothing back to the connecting
      // side, so (unlike ESCR) we must not write to the socket here.
      await legacy.verifyEnvelope(message);
      logger.info('Auto-detected LEGACY; verification success');
    }

    Future<void> handleEscrLine(String response) async {
      for (final cu in response.codeUnits) {
        if (isUnprintable(cu)) {
          throw RAVE(
            'received unprintable code units',
            RAVEReason.malformedChallengeResponse,
          );
        }
      }
      final verified = await escr.verifyChallengeResponse(response);
      if (!verified) {
        throw RAVE(
          '(but verifyChallengeResponse did not throw an exception)',
          RAVEReason.signatureVerificationFailed,
        );
      }
      if (escr.sessionId != _sessionId) {
        throw RAVE(
          'ESCR response for session ${escr.sessionId}'
          ' on the socket for session $_sessionId',
          RAVEReason.dataMismatch,
        );
      }
      if (escr.isSideA != isSideA) {
        throw RAVE(
          'ESCR response for side ${escr.isSideA! ? 'A' : 'B'}'
          ' on the socket for side ${isSideA ? 'A' : 'B'}',
          RAVEReason.dataMismatch,
        );
      }
      if (escr.atSign != atSign) {
        throw RAVE(
          'ESCR response signed by ${escr.atSign} on the socket for $atSign',
          RAVEReason.dataMismatch,
        );
      }
      onEscrVerified?.call(escr.signingKeyUri!);
      logger.info('Auto-detected ESCR; verification success');
      socket.writeln('ok');
      await socket.flush();
    }

    // Gives this socket mode [m] while it is still waiting; the caller holds
    // [mutex]. An ESCR socket is challenged at once; a legacy one is sent
    // nothing and waits for its signed envelope.
    Future<void> resolveLocked(RelayAuthMode m) async {
      if (mode != 'waiting' || authenticated) return;
      stopWaiting();
      if (m == RelayAuthMode.escr) {
        mode = 'escr';
        logger.info('resolving to ESCR; sending challenge');
        socket.writeln(escr.challenge);
        await socket.flush();
      } else {
        mode = 'legacy';
        logger.info('resolving to LEGACY; awaiting signed envelope');
      }
    }

    Future<void> resolve(RelayAuthMode m) async {
      await mutex.acquire();
      try {
        await resolveLocked(m);
      } catch (e) {
        await failAuth(e);
      } finally {
        mutex.release();
      }
    }

    final RelayAuthMode? known = _knownMode;
    if (known == null) {
      final Future<void> Function(RelayAuthMode) resolver = resolve;
      waitingFor = resolver;
      _waiting.add(resolver);
      logger.info(
        'waiting for the client to name this side\'s mode,'
        ' or for a legacy envelope',
      );
    }

    subscription = socket.listen(
      (Uint8List data) async {
        // NOTE: skip the mutex only when no chunk holds or awaits it, or this
        // chunk would overtake the bytes queued ahead of it.
        if (authenticated && !mutex.isLocked) {
          if (!sc.isClosed) {
            try {
              sc.add(data);
            } catch (err) {
              logger.shout('post-verify sc.add failed with $err');
            }
          }
          return;
        }
        await mutex.acquire();
        try {
          if (authenticated) {
            if (!sc.isClosed) {
              try {
                sc.add(data);
              } catch (err) {
                logger.shout('post-verify sc.add failed with $err');
              }
            }
            return;
          }

          // Unsolicited bytes on a socket still waiting for a mode can only be
          // legacy (a JSON object); an ESCR peer sends nothing until we
          // challenge it.
          if (mode == 'waiting') {
            stopWaiting();
            final int? firstByte = data.isNotEmpty ? data.first : null;
            if (firstByte == 0x7B /* '{' */ ) {
              mode = 'legacy';
            } else {
              throw RAVE(
                'Unexpected first byte $firstByte from connecting side'
                ' (legacy sends a JSON object; ESCR sends nothing until'
                ' challenged)',
                RAVEReason.malformedChallengeResponse,
              );
            }
          }

          if (buffer.length + data.length >
              RelayAuthVerifier.maxAuthBufferLength) {
            throw RAVE(
              'Too much data from client'
              ' (more than ${RelayAuthVerifier.maxAuthBufferLength} bytes)',
              RAVEReason.malformedChallengeResponse,
            );
          }
          buffer.addAll(data);
          if (buffer.contains(10)) {
            final int idx = buffer.indexOf(10);
            final List<int> lineBytes = buffer.sublist(0, idx);
            buffer.removeRange(0, idx + 1);
            final String line = String.fromCharCodes(lineBytes);
            if (mode == 'legacy') {
              await handleLegacyLine(line);
            } else {
              await handleEscrLine(line.trim());
            }
            completeSuccess();
          }
        } catch (e) {
          await failAuth(e);
        } finally {
          mutex.release();
        }
      },
      // NOTE: close through the mutex, behind any chunks still queued on it,
      // or their bytes are dropped.
      onError: (Object error, StackTrace stackTrace) async {
        stopWaiting();
        await mutex.acquire();
        try {
          failIfUnauthenticated(
            'the socket failed before it authenticated: $error',
          );
          if (!sc.isClosed) {
            sc.addError(error);
            unawaited(sc.close());
          }
        } finally {
          mutex.release();
        }
      },
      onDone: () async {
        stopWaiting();
        await mutex.acquire();
        try {
          failIfUnauthenticated('the socket closed before it authenticated');
          if (!sc.isClosed) {
            unawaited(sc.close());
          }
        } finally {
          mutex.release();
        }
      },
    );

    if (known != null) {
      await mutex.acquire();
      try {
        await resolveLocked(known);
      } catch (e) {
        await failAuth(e);
      } finally {
        mutex.release();
      }
    }

    return completer.future;
  }
}
