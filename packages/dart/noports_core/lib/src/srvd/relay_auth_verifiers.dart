import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:mutex/mutex.dart';

import '../../utils.dart';

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
  static final maxAuthBufferLength = 4096;

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
///     'sk':'public:some_key.some.namespace@atSign'
///   }
///   ```
/// 7. Verify that the contents of the payload are as expected (session id, challenge)
/// 8. Fetch the public signing key
/// 9. Verify the signature of the payload using the public signing key,
///   hashingAlgo and signingAlgo
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

  final AtChops atChops = AtChopsImpl(AtChopsKeys());

  final RelayAuthVerifyHelper helper;

  final String challenge = AtChopsUtil.generateSymmetricKey(
    EncryptionKeyType.aes256,
  ).key;

  /// If [randomlyFail] > 0 && random.nextInt([randomlyFail]) == 0
  /// then fail the verification
  final int randomlyFail;

  /// If [randomlyAddLatency] > 0 && random.nextInt([randomlyAddLatency]) == 0
  /// then add (100 + random.nextInt(3900))ms delay
  final int randomlyAddLatency;

  late final AtSignLogger logger;

  bool? isSideA;

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
    // TODO Eliminate re-entrance race conditions
    // TODO While not a problem right now, is laying a trap for the future
    atSign = null;
    isSideA = null;
    sessionId = null;

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
    sessionId = responseParts[0];
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

    var encryptionAlgo = AESEncryptionAlgo(AESKey(aesKey64));
    String envelope64;
    try {
      envelope64 = (await atChops
          .decryptString(
            envelopeEncrypted64,
            EncryptionKeyType.aes256,
            encryptionAlgorithm: encryptionAlgo,
            iv: InitialisationVector(base64Decode(iv)),
          ))
          .result;
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
    ///     'sk':'public:some_key.some.namespace@atSign'
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
    if (signedPayload['sid'] != sessionId) {
      throw RAVE(
        'signedPayload sessionId (${signedPayload['sid']})'
        ' does not match expected sessionId ($sessionId)',
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
    atSign = publicSigningKeyUri
        .substring(publicSigningKeyUri.lastIndexOf('@'))
        .toAtsign();

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
    String publicSigningKey = await helper.lookup(
      sessionId!,
      publicSigningKeyUri,
    );

    /// Verify the signature of the payload
    final hashingAlgo = HashingAlgoType.values.byName(envelope['ha']);
    final signingAlgo = SigningAlgoType.values.byName(envelope['sa']);

    AtSigningVerificationInput input =
        AtSigningVerificationInput(
            jsonEncode(signedPayload),
            base64Decode(envelope['s']),
            publicSigningKey,
          )
          ..signingAlgorithm = DefaultSigningAlgo(null, hashingAlgo)
          ..signingMode = AtSigningMode.data
          ..signingAlgoType = signingAlgo
          ..hashingAlgoType = hashingAlgo;

    AtSigningResult atSigningResult = atChops.verify(input);
    bool verified = atSigningResult.result == true;
    if (!verified) {
      throw RAVE(
        'Signatures did not match.',
        RAVEReason.signatureVerificationFailed,
      );
    }

    return verified;
  }

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    StreamController<Uint8List> sc = StreamController();
    logger.info('starting listen');
    List<int> buffer = [];

    /// 1. Sends a challenge to the client, terminated with a newline
    socket.writeln(challenge);
    await socket.flush();

    Mutex listenMutex = Mutex();

    socket.listen(
      (Uint8List data) async {
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
      onError: (Object error, StackTrace stackTrace) {
        if (!sc.isClosed) {
          sc.addError(error);
          sc.close();
        }
      },
      onDone: () {
        if (!sc.isClosed) {
          sc.close();
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
  /// sent in the payload. Throws a [RAVE] on any failure; returns normally
  /// on success.
  ///
  /// Extracted from [verifySocketAuth] so that [RelayAuthVerifierAuto] can
  /// reuse the exact same legacy verification once it has detected, at the
  /// socket level, that a connecting side is using legacy auth.
  ///
  /// Synchronous: nothing here needs to await, and keeping it sync lets the
  /// legacy [verifySocketAuth] `onData` callback stay synchronous (so a second
  /// data chunk cannot re-enter it mid-verification).
  void verifyEnvelope(String message) {
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

    final AtSigningVerificationInput input =
        AtSigningVerificationInput(
            dataToVerify,
            base64Decode(envelope['signature']),
            publicKey,
          )
          ..signingAlgorithm = DefaultSigningAlgo(null, hashingAlgo)
          ..signingMode = AtSigningMode.data
          ..signingAlgoType = signingAlgo
          ..hashingAlgoType = hashingAlgo;

    final AtSigningResult atSigningResult = AtChopsImpl(
      AtChopsKeys(),
    ).verify(input);
    if (atSigningResult.result != true) {
      logger.shout('$tag : verification FAILURE : ${atSigningResult.result}');
      throw RAVE(
        'Signature verification failed. Signatures did not match.',
        RAVEReason.signatureVerificationFailed,
      );
    }
    logger.info('$tag : verification SUCCESS : ${atSigningResult.result}');
  }

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    StreamController<Uint8List> sc = StreamController();
    logger.info('SignatureAuthVerifier for $tag: starting listen');
    List<int> buffer = [];
    socket.listen(
      (Uint8List data) {
        if (authenticated) {
          if (!sc.isClosed) {
            try {
              sc.add(data);
            } catch (err) {
              logger.shout('post-verify sc.add failed with $err');
            }
          }
        } else {
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

              verifyEnvelope(message);

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
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!sc.isClosed) {
          sc.addError(error);
          sc.close();
        }
      },
      onDone: () {
        if (!sc.isClosed) {
          sc.close();
        }
      },
    );
    return completer.future;
  }
}

/// Default detection window for [RelayAuthVerifierAuto] (see that class).
const int defaultRelayAuthDetectWindowMs = 500;

/// A [RelayAuthVerifier] which auto-detects, per socket, whether the connecting
/// side is using ESCR ([RelayAuthVerifierESCR]) or legacy ([RelayAuthVerifierLegacy])
/// auth, without being told in advance. This lets the client and daemon each
/// use the strongest auth they support, independently, and frees the client from
/// having to learn the daemon's capabilities (via the daemon ping) before it can
/// commit to a session-wide auth mode.
///
/// Detection relies on the opposite "who speaks first" semantics of the two
/// schemes, both of which are left byte-for-byte unchanged on the wire:
/// - A **legacy** connecting side writes its JSON signature envelope (starting
///   with `{`) immediately on connect and never reads first.
/// - An **ESCR** connecting side stays silent until the relay sends it a
///   challenge, then replies `${sessionId}:${payload}`.
///
/// So this verifier:
/// 1. Begins listening and starts a one-shot [detectWindow] timer.
/// 2. If inbound data arrives first, it must be legacy — the first byte is `{` —
///    so we run legacy verification (looking up the connecting atSign's public
///    key lazily, only on this branch, unless one was pre-supplied).
/// 3. If the window elapses with no data, we assume ESCR: send the challenge and
///    run ESCR verification.
///
/// Trade-off: because the ESCR wire is unchanged (the peer waits to be
/// challenged), every ESCR socket waits out [detectWindow] before the challenge
/// is sent. [detectWindow] must exceed a legacy peer's first-packet arrival
/// (≈ one RTT after connect); if it is too short, a slow legacy peer is misread
/// as ESCR and, having been sent a challenge it does not read, its onward stream
/// is corrupted. Raise it for high-latency legacy peers; lower it to speed ESCR.
///
/// The window is only the *fallback*. When the mode for a side is known ahead
/// of the socket connecting — via the [knownMode] constructor argument (side A,
/// whose mode the requesting client set in its own request) or via
/// [setKnownMode] (side B, once the client has learnt the daemon's mode and
/// sent the relay a definitive auth-modes notification) — detection is skipped:
/// a known ESCR side is challenged immediately, and a known legacy side simply
/// waits for its envelope with the timer cancelled (so it is never misread).
/// A known mode is applied only while the socket is still being detected, never
/// after it has committed by sending bytes, so a stale/incorrect ESCR hint can
/// never challenge a socket that has already spoken legacy.
class RelayAuthVerifierAuto implements RelayAuthVerifier {
  @override
  final String tag;

  final RelayAuthVerifyHelper helper;

  /// The atSign expected on this side of the tunnel. On the two-port relay path
  /// the side (A/B) is known from which port the socket arrived on, so we know
  /// the atSign up front; it is used for the legacy public-key lookup.
  final String expectedAtSign;

  final String _sessionId;

  /// Legacy branch: the data whose signature is verified — the JSON encoding of
  /// `{sessionId, clientNonce, rvdNonce}`.
  final String dataToVerify;

  /// Legacy branch: the rvdNonce which must appear in the signed payload.
  final String rvdNonce;

  /// Legacy branch: a pre-supplied public key for [expectedAtSign]. If null it
  /// is looked up lazily (and only if the socket turns out to be legacy).
  final String? publicKey;

  /// How long to wait for the connecting side to speak (legacy) before assuming
  /// ESCR and sending a challenge.
  final Duration detectWindow;

  late final AtSignLogger logger;

  /// The composed ESCR verifier, used if the socket turns out to be ESCR. It
  /// owns the challenge and the ESCR verification logic, and is the source of
  /// [atSign] / [sessionId] / [isSideA] once ESCR has been verified.
  late final RelayAuthVerifierESCR _escr;

  /// The mode this side will use, if known ahead of detection. Set from the
  /// constructor (side A) or [setKnownMode] (side B). Null means "detect".
  RelayAuthMode? _knownMode;

  /// Set by [verifySocketAuth] while it is running so [setKnownMode] can apply a
  /// mode to the in-flight detection. Null before the socket has connected.
  Future<void> Function(RelayAuthMode)? _resolveKnownMode;

  RelayAuthVerifierAuto(
    this.tag,
    this.helper, {
    required String atSign,
    required String sessionId,
    required this.dataToVerify,
    required this.rvdNonce,
    required this.detectWindow,
    this.publicKey,
    RelayAuthMode? knownMode,
  }) : expectedAtSign = atSign,
       _sessionId = sessionId {
    logger = AtSignLogger(' $runtimeType ($tag) ');
    _escr = RelayAuthVerifierESCR(tag, helper);
    _knownMode = knownMode;
  }

  /// Tell this verifier which mode the connecting side will use, so it can skip
  /// the [detectWindow] heuristic. Safe to call at any time and more than once:
  /// the mode is applied only while the socket is still being detected (never
  /// after it has committed by sending bytes), so an ESCR hint can never
  /// challenge a socket that has already spoken legacy.
  void setKnownMode(RelayAuthMode mode) {
    _knownMode = mode;
    final resolve = _resolveKnownMode;
    if (resolve != null) {
      unawaited(resolve(mode));
    }
  }

  @override
  Atsign? get atSign => _escr.atSign ?? expectedAtSign.toAtsign();

  @override
  String? get sessionId => _escr.sessionId ?? _sessionId;

  /// `true` for side A (client), `false` for side B (daemon). Only populated
  /// when the socket was verified via ESCR.
  bool? get isSideA => _escr.isSideA;

  @override
  Future<(bool, Stream<Uint8List>?)> verifySocketAuth(Socket socket) async {
    final completer = Completer<(bool, Stream<Uint8List>?)>();
    final sc = StreamController<Uint8List>();
    final buffer = <int>[];
    bool authenticated = false;

    // 'detecting' -> 'legacy' | 'escr'. Guarded by [mutex] so the detection
    // timer and inbound-data events cannot race to pick different modes.
    String mode = 'detecting';
    final mutex = Mutex();
    Timer? detectTimer;

    logger.info(
      'starting auto-detect listen'
      ' (window ${detectWindow.inMilliseconds}ms)',
    );

    Future<void> failAuth(Object e) async {
      logger.shout('auto verification FAILED with exception : $e');
      if (!completer.isCompleted) {
        try {
          socket.writeln('Socket auth failed');
          await socket.flush();
          socket.destroy();
        } catch (_) {
        } finally {
          completer.completeError('Error during socket authentication: $e');
        }
      }
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
      legacy.verifyEnvelope(message);
      logger.info('Auto-detected LEGACY; verification success');
      completeSuccess();
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
      final verified = await _escr.verifyChallengeResponse(response);
      if (!verified) {
        throw RAVE(
          '(but verifyChallengeResponse did not throw an exception)',
          RAVEReason.signatureVerificationFailed,
        );
      }
      logger.info('Auto-detected ESCR; verification success');
      socket.writeln('ok');
      await socket.flush();
      completeSuccess();
    }

    // Resolve this side to a concrete mode, skipping detection. The caller of
    // [resolveLocked] must already hold [mutex]; [resolve] acquires it. A known
    // ESCR side is challenged immediately; a known legacy side just waits for
    // its signed envelope (timer cancelled). Both are no-ops once the socket
    // has already committed to a mode, so a stale ESCR hint can never challenge
    // a socket that has already sent bytes.
    Future<void> resolveLocked(RelayAuthMode m) async {
      if (mode != 'detecting' || authenticated) return;
      detectTimer?.cancel();
      if (m == RelayAuthMode.escr) {
        mode = 'escr';
        logger.info('resolving to ESCR; sending challenge');
        socket.writeln(_escr.challenge);
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

    // Let setKnownMode() (called when the client's definitive auth-modes
    // notification arrives) steer this in-flight detection.
    _resolveKnownMode = resolve;

    socket.listen(
      (Uint8List data) async {
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

          // The first unsolicited bytes can only be legacy (a JSON object);
          // an ESCR peer sends nothing until we challenge it.
          if (mode == 'detecting') {
            detectTimer?.cancel();
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
          }
        } catch (e) {
          await failAuth(e);
        } finally {
          mutex.release();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!sc.isClosed) {
          sc.addError(error);
          sc.close();
        }
      },
      onDone: () {
        if (!sc.isClosed) {
          sc.close();
        }
      },
    );

    // If the mode is already known (side A from the request, or a side B hint
    // that arrived before the socket connected) apply it now and skip the
    // window; otherwise fall back to the timing heuristic.
    await mutex.acquire();
    try {
      if (mode == 'detecting' && !authenticated) {
        if (_knownMode != null) {
          await resolveLocked(_knownMode!);
        } else {
          detectTimer = Timer(detectWindow, () {
            logger.info(
              'no data within ${detectWindow.inMilliseconds}ms; assuming ESCR',
            );
            resolve(RelayAuthMode.escr);
          });
        }
      }
    } catch (e) {
      await failAuth(e);
    } finally {
      mutex.release();
    }

    return completer.future;
  }
}
