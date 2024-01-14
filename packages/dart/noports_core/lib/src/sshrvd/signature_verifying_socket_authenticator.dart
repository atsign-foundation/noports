import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_utils/at_logger.dart';

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
class SignatureAuthVerifier {
  static final AtSignLogger logger = AtSignLogger('SignatureAuthVerifier');

  /// Public key of the signing algorithm used to sign the data
  String publicKey;

  /// data that was signed, this is the data that should be matched once the signature is verified
  String dataToVerify;

  /// string generated by rvd which should be included in auth strings from sshnp and sshnpd
  String rvdNonce;

  /// a tag to help decipher logs
  String tag;

  SignatureAuthVerifier(
    this.publicKey,
    this.dataToVerify,
    this.rvdNonce,
    this.tag,
  );

  AtSigningResult _verifySignature(AtSigningVerificationInput input) {
    AtChopsKeys atChopsKeys = AtChopsKeys();
    AtChops atChops = AtChopsImpl(atChopsKeys);
    return atChops.verify(input);
  }

  Future<(bool, Stream<Uint8List>?)> authenticate(Socket socket) async {
    Completer<(bool, Stream<Uint8List>?)> completer = Completer();
    bool authenticated = false;
    StreamController<Uint8List> sc = StreamController();
    logger.info('SignatureAuthVerifier $tag: starting listen');
    socket.listen((Uint8List data) {
      if (authenticated) {
        sc.add(data);
      } else {
        try {
          final message = String.fromCharCodes(data);
          logger.info('SignatureAuthVerifier $tag received data: $message');
          // Expected message to be the JSON format with the below structure:
          // {
          // "signature":"<signature>",
          // "hashingAlgo":"<algo>",
          // "signingAlgo":"<algo>",
          // "payload":{<the data which was signed>}
          // }
          var envelope = jsonDecode(message);

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

          AtSigningResult atSigningResult = _verifySignature(input);
          logger.info('Signing verification outcome is:'
              ' ${atSigningResult.result}');
          bool result = atSigningResult.result;

          if (result == false) {
            completer.completeError(
                'Signature verification failed. Signatures did not match.');
            return;
          }

          authenticated = true;
          completer.complete((true, sc.stream));
        } catch (e) {
          completer.completeError('Error during socket authentication: $e');
        }
      }
    }, onError: (error) => sc.addError(error), onDone: () => sc.close());
    return completer.future;
  }
}
