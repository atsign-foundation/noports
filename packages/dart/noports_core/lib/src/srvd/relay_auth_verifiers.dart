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
  String? atSign;

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
      abbreviated = '${response.substring(0, 40)}'
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
      envelope64 = atChops
          .decryptString(
            envelopeEncrypted64,
            EncryptionKeyType.aes256,
            encryptionAlgorithm: encryptionAlgo,
            iv: InitialisationVector(base64Decode(iv)),
          )
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
    atSign = publicSigningKeyUri.substring(
      publicSigningKeyUri.lastIndexOf('@'),
    );

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

    AtSigningVerificationInput input = AtSigningVerificationInput(
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

              try {
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
                    completer.completeError(
                      'Error during socket authentication: $e',
                    );
                  }
                }
              }
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
  /// send in the payload
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

            try {
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
              logger.finer('$tag received data: $message');
              var envelope = jsonDecode(message);
              logger.finer('$tag decoded JSON message OK');

              final hashingAlgo = HashingAlgoType.values.byName(
                envelope['hashingAlgo'],
              );
              final signingAlgo = SigningAlgoType.values.byName(
                envelope['signingAlgo'],
              );

              var payload = envelope['payload'];
              if (payload == null || payload is! Map) {
                if (!completer.isCompleted) {
                  completer.completeError(
                    'Received an auth signature'
                    ' which does not include the payload',
                  );
                }
                return;
              }
              if (payload['rvdNonce'] != rvdNonce) {
                if (!completer.isCompleted) {
                  completer.completeError(
                    'Received rvdNonce which does not match what is expected',
                  );
                }
                return;
              }

              AtSigningVerificationInput input = AtSigningVerificationInput(
                dataToVerify,
                base64Decode(envelope['signature']),
                publicKey,
              )
                ..signingAlgorithm = DefaultSigningAlgo(null, hashingAlgo)
                ..signingMode = AtSigningMode.data
                ..signingAlgoType = signingAlgo
                ..hashingAlgoType = hashingAlgo;

              AtChopsKeys atChopsKeys = AtChopsKeys();
              AtChops atChops = AtChopsImpl(atChopsKeys);
              AtSigningResult atSigningResult = atChops.verify(input);
              bool result = atSigningResult.result;

              if (result == false) {
                logger.shout(
                  '$tag :'
                  ' verification FAILURE :'
                  ' ${atSigningResult.result}',
                );
                if (!completer.isCompleted) {
                  completer.completeError(
                    'Signature verification failed. Signatures did not match.',
                  );
                }
                return;
              }

              logger.info(
                '$tag :'
                ' verification SUCCESS :'
                ' ${atSigningResult.result}',
              );
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
            } catch (e) {
              logger.shout(
                '$tag :'
                ' verification FAILED with exception :'
                ' $e',
              );

              if (!completer.isCompleted) {
                completer.completeError(
                  'Error during socket authentication: $e',
                );
              }
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
