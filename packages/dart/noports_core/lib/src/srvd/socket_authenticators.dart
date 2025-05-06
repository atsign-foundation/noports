import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_commons/atsign.dart';
import 'package:at_utils/at_logger.dart';

abstract interface class RelayAuthVerifier {
  /// The authentication which is expected
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket);

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
  static final AtSignLogger logger = AtSignLogger(' SocketAuthenticatorV1 ');

  @override
  String? atSign;

  @override
  String? sessionId;

  @override
  final String tag;

  RelayAuthVerifierV1(this.tag);

  @override
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket) async {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    StreamController<Uint8List> sc = StreamController();
    logger.info('SignatureAuthVerifier for $tag: starting listen');
    List<int> buffer = [];

    /// 1. Sends a challenge to the client, terminated with a newline
    String challenge = 'some random string';
    socket.writeln(challenge);

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
            /// 2. Receives `${sessionId}:${auth-payload-as-base64}\n` from client
            final response = String.fromCharCodes(authBuffer);
            logger.finer('$tag received data: $response');

            // TODO Split by ':' - expect two parts - sessionId, authPayload
            String sessionId = 'some_session_id';
            String encryptedAuthEnvelope64 = 'some_base_64';
            String encryptedAuthEnvelopeJson = String.fromCharCodes(
              base64Decode(encryptedAuthEnvelope64),
            );

            /// TODO 3. Verifies that `sessionId` is currently active

            /// TODO 4. Auth payload is json like this: `{'iv':'dsahjk','e':'ecehwuorhi'}`
            Map encryptedAuthEnvelope = jsonDecode(encryptedAuthEnvelopeJson);
            String iv = encryptedAuthEnvelope['iv'];
            String envelopeEncrypted64 = encryptedAuthEnvelope['e'];

            // TODO Fetch the session's AES Key
            String aesKey64 = 'aes key as base64';

            /// TODO 5. Use session's AES key and the provided IV to decrypt the auth envelope
            logger.finer('Decrypting using $aesKey64 and $iv'); // TODO remove
            String envelope64 = 'decrypted from $envelopeEncrypted64';
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
              completer.completeError(
                  'Received an auth signature which does not include the payload');
              return;
            }
            if (signedPayload['sid'] != sessionId) {
              completer.completeError(
                  'signedPayload sessionId (${signedPayload['sid']})'
                  ' does not match expected sessionId ($sessionId)');
            }
            if (signedPayload['c'] != challenge) {
              completer.completeError(
                  'signedPayload challenge (${signedPayload['c']})'
                  ' does not match challenge we issued ($challenge)');
            }

            /// TODO 8. Fetch the public signing key
            String publicSigningKey = 'abcde';

            /// TODO 9. Verify the signature of the payload
            final hashingAlgo =
                HashingAlgoType.values.byName(envelope['hashingAlgo']);
            final signingAlgo =
                SigningAlgoType.values.byName(envelope['signingAlgo']);

            AtSigningVerificationInput input = AtSigningVerificationInput(
                jsonEncode(signedPayload),
                base64Decode(envelope['s']),
                publicSigningKey)
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

            /// TODO 10. If all successful, return (true, dataStream)
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
///
class RelayAuthVerifierLegacy implements RelayAuthVerifier {
  static final AtSignLogger logger =
      AtSignLogger(' SocketAuthenticatorLegacy ');

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
  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket) async {
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
