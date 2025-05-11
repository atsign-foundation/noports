import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_commons/atsign.dart';
import 'package:at_utils/at_logger.dart';
import 'package:mutex/mutex.dart';

enum RAVEReason {
  jsonDecodeFailed,
  malformedChallengeResponse,
  sessionNotActive,
  dataMismatch,
  decryptionFailed,
  signatureVerificationFailed,
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
  Future<String> lookupAtKey(String atKey);

  Future<bool> sessionIsActive(String sessionId);

  Future<String> relayAuthAesKey(String sessionId);
}

abstract interface class RelayAuthVerifier {
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

/// Authenticates new socket connection as follows:
/// 1. Send a challenge to the client, terminated with a newline
/// 2. Receive `${sessionId}:${auth-payload-as-base64}\n` from client
/// 3. Verify that `sessionId` is currently active
/// 4. Auth payload is json like this: `{'iv':'dsahjk','e':'ecehwuorhi'}`
/// 5. Fetch session's AES key. Use it and the provided IV to decrypt the auth envelope
/// 6. Expect decrypted auth envelope to look like this:
///   ```
///   {
///     'p':{'sid':'session-id','c':'challenge'},
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
/// 10. If all successful, return (true, dataStream)
class RelayAuthVerifierV1 implements RelayAuthVerifier {
  static final AtSignLogger logger = AtSignLogger(' RelayAuthVerifierV1 ');

  @override
  String? atSign;

  @override
  String? sessionId;

  @override
  final String tag;

  final AtChops atChops = AtChopsImpl(AtChopsKeys());

  final RelayAuthVerifyHelper helper;

  final String challenge =
      AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;

  RelayAuthVerifierV1(this.tag, this.helper);

  Future<bool> verifyChallengeResponse(String response) async {
    // Split by ':' - expect two parts - sessionId, encryptedAuthEnvelope64
    List<String> responseParts = response.split(':');
    // TODO unit test for parts
    if (responseParts.length != 2) {
      throw RAVE(
        'Expected <sid>:<payload> but got $response',
        RAVEReason.malformedChallengeResponse,
      );
    }
    String sessionId = responseParts[0];
    String encryptedAuthEnvelope64 = responseParts[1];
    String encryptedAuthEnvelopeJson = String.fromCharCodes(
      base64Decode(encryptedAuthEnvelope64),
    );

    /// 3. Verify that `sessionId` is currently active
    /// TODO unit test for active
    final bool active = await helper.sessionIsActive(sessionId);
    if (!active) {
      throw RAVE(
        'Session $sessionId is not active',
        RAVEReason.sessionNotActive,
      );
    }

    /// 4. Auth payload is json like this: `{'iv':'dsahjk','e':'ecehwuorhi'}`
    /// TODO Unit tests for valid auth payload
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
    /// TODO unit tests for failed to decrypt
    // Fetch the session's AES Key
    String aesKey64 = await helper.relayAuthAesKey(sessionId);

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
    String envelopeJson = String.fromCharCodes(
      base64Decode(envelope64),
    );

    /// TODO 6. Expect decrypted auth envelope to look like this:
    ///   ```
    ///   {
    ///     'p':{'sid':'session-id','c':'challenge'},
    ///     's':'signature of p encoded as string',
    ///     'ha':'hashingAlgo',
    ///     'sa':'signingAlgo',
    ///     'sk':'public:some_key.some.namespace@atSign'
    ///   }
    ///   ```
    Map envelope = jsonDecode(envelopeJson);

    /// TODO 7. Verify that the contents of the payload are as expected (session id, challenge)
    var signedPayload = envelope['p'];
    if (signedPayload == null || signedPayload is! Map) {
      throw RAVE(
        'Decrypted challenge response envelope does not contain signedPayload',
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

    /// TODO 8. Fetch the public signing key
    String publicSigningKey = await helper.lookupAtKey(envelope['sk']);

    /// TODO 9. Verify the signature of the payload
    final hashingAlgo = HashingAlgoType.values.byName(envelope['ha']);
    final signingAlgo = SigningAlgoType.values.byName(envelope['sa']);

    AtSigningVerificationInput input = AtSigningVerificationInput(
        jsonEncode(signedPayload),
        base64Decode(envelope['s']),
        publicSigningKey)
      ..signingAlgorithm = DefaultSigningAlgo(null, hashingAlgo)
      ..signingMode = AtSigningMode.data
      ..signingAlgoType = signingAlgo
      ..hashingAlgoType = hashingAlgo;

    AtSigningResult atSigningResult = atChops.verify(input);
    bool verified = atSigningResult.result == true;
    if (!verified) {
      logger.shout('SignatureAuthVerifier $tag :'
          ' verification FAILURE. ');
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
    logger.info('SignatureAuthVerifier for $tag: starting listen');
    List<int> buffer = [];

    /// 1. Sends a challenge to the client, terminated with a newline
    socket.writeln(challenge);

    Mutex listenMutex = Mutex();

    socket.listen((Uint8List data) async {
      await listenMutex.acquire();
      try {
        if (authenticated) {
          sc.add(data);
        } else {
          // TODO maximum buffer size check to prevent dos attacks
          // TODO unit test for same
          buffer.addAll(data);
          if (buffer.contains(10)) {
            logger.finer('original buffer length ${buffer.length}');
            List<int> authBuffer = buffer.sublist(0, buffer.indexOf(10));
            logger.finer('authBuffer length ${authBuffer.length}');
            buffer.removeRange(0, buffer.indexOf(10) + 1);
            logger.finer('remaining buffer length ${buffer.length}');

            try {
              /// 2. Receives `${sessionId}:${auth-payload-as-base64}\n` from client
              /// TODO try-catch check here?
              /// TODO unit test for this
              final response = String.fromCharCodes(authBuffer);
              logger.finer('$tag received data: $response');

              bool verified = await verifyChallengeResponse(response);

              if (!verified) {
                throw RAVE(
                  '(but verifyChallengeResponse did not throw an exception)',
                  RAVEReason.signatureVerificationFailed,
                );
              }

              /// TODO 10. If all successful, return (true, dataStream)
              authenticated = true;
              completer.complete((true, sc.stream));

              if (buffer.isNotEmpty) {
                sc.add(Uint8List.fromList(buffer));
              }
            } catch (e) {
              logger.shout('SignatureAuthVerifier $tag :'
                  ' verification FAILED with exception :'
                  ' $e');

              completer.completeError('Error during socket authentication: $e');
            }
          }
        }
      } finally {
        listenMutex.release();
      }
    }, onError: (Object error, StackTrace stackTrace) {
      sc.addError(error);

      sc.close();
    }, onDone: () => sc.close());
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
  static final AtSignLogger logger =
      AtSignLogger(' RelayAuthVerifierLegacy ');

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

  RelayAuthVerifierLegacy(
    this.publicKey,
    this.dataToVerify,
    this.rvdNonce,
    this.tag,
    this.atSign,
    this.sessionId,
  );

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
    socket.listen((Uint8List data) {
      if (authenticated) {
        sc.add(data);
      } else {
        buffer.addAll(data);
        if (buffer.contains(10)) {
          logger.finer('original buffer length ${buffer.length}');
          List<int> authBuffer = buffer.sublist(0, buffer.indexOf(10));
          logger.finer('authBuffer length ${authBuffer.length}');
          buffer.removeRange(0, buffer.indexOf(10) + 1);
          logger.finer('remaining buffer length ${buffer.length}');

          try {
            final message = String.fromCharCodes(authBuffer);
            logger.finer('SignatureAuthVerifier $tag received data: $message');
            var envelope = jsonDecode(message);
            logger.finer('SignatureAuthVerifier $tag decoded JSON message OK');

            final hashingAlgo =
                HashingAlgoType.values.byName(envelope['hashingAlgo']);
            final signingAlgo =
                SigningAlgoType.values.byName(envelope['signingAlgo']);

            var payload = envelope['payload'];
            if (payload == null || payload is! Map) {
              completer.completeError(
                  'Received an auth signature which does not include the payload');
              return;
            }
            if (payload['rvdNonce'] != rvdNonce) {
              completer.completeError(
                  'Received rvdNonce which does not match what is expected');
              return;
            }

            AtSigningVerificationInput input = AtSigningVerificationInput(
                dataToVerify, base64Decode(envelope['signature']), publicKey)
              ..signingAlgorithm = DefaultSigningAlgo(null, hashingAlgo)
              ..signingMode = AtSigningMode.data
              ..signingAlgoType = signingAlgo
              ..hashingAlgoType = hashingAlgo;

            AtChopsKeys atChopsKeys = AtChopsKeys();
            AtChops atChops = AtChopsImpl(atChopsKeys);
            AtSigningResult atSigningResult = atChops.verify(input);
            bool result = atSigningResult.result;

            if (result == false) {
              logger.shout('SignatureAuthVerifier $tag :'
                  ' verification FAILURE :'
                  ' ${atSigningResult.result}');
              completer.completeError(
                  'Signature verification failed. Signatures did not match.');
              return;
            }

            logger.info('SignatureAuthVerifier $tag :'
                ' verification SUCCESS :'
                ' ${atSigningResult.result}');
            authenticated = true;
            completer.complete((true, sc.stream));

            if (buffer.isNotEmpty) {
              sc.add(Uint8List.fromList(buffer));
            }
          } catch (e) {
            logger.shout('SignatureAuthVerifier $tag :'
                ' verification FAILED with exception :'
                ' $e');

            completer.completeError('Error during socket authentication: $e');
          }
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      sc.addError(error);
      sc.close();
    }, onDone: () => sc.close());
    return completer.future;
  }
}
