import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';

abstract class SocketAuthenticator {
  authenticate(Socket? socket);
}

class EmptySocketAuthenticator extends SocketAuthenticator {
  @override
  authenticate(Socket? socket) {
    //Do Nothing
  }
}

///
/// Signs the sessionId and create a JSON in the following format with the signed data
///
/// {
///       "signature":"<base64 encoded signature>",
///       "hashingAlgo":"<algo>",
///       "signingAlgo":"<algo>"
///  }
class SignatureAuthenticator extends SocketAuthenticator{
  String sessionId;
  String privateKey;

  SignatureAuthenticator(this.sessionId, this.privateKey);

  @override
  authenticate(Socket? socket) {
      // Sign and write to the socket
    String signedData = sign(sessionId);
    socket?.write(signedData);
  }

  String sign(String dataToSign) {
    AtEncryptionKeyPair atEncryptionKeyPair =
    AtEncryptionKeyPair.create('', privateKey);
    AtPkamKeyPair atPkamKeyPair = AtPkamKeyPair.create('', privateKey);
    AtChopsKeys atChopsKeys =
    AtChopsKeys.create(atEncryptionKeyPair, atPkamKeyPair);
    AtChops atChops = AtChopsImpl(atChopsKeys);

    Map responseMap = {};
    AtSigningInput atSigningInput = AtSigningInput(dataToSign)
      ..signingAlgorithm = DefaultSigningAlgo(
          atChops.atChopsKeys.atEncryptionKeyPair, HashingAlgoType.sha256);
    var atSigningResponse = atChops.sign(atSigningInput);

    responseMap['signature'] = atSigningResponse.result;
    responseMap['hashingAlgo'] =
        _getHashingAlgo(atSigningResponse.atSigningMetaData.hashingAlgoType);
    responseMap['signingAlgo'] =
        _getSigningAlgo(atSigningResponse.atSigningMetaData.signingAlgoType);

    return jsonEncode(responseMap);
  }

  String _getHashingAlgo(HashingAlgoType? hashingAlgoType) {

    switch(hashingAlgoType) {
      case HashingAlgoType.sha256:
          return "sha256";
        case HashingAlgoType.sha512:
          return "sha512";
      case HashingAlgoType.md5:
        return "md5";
      default:
        return "sha256";
    }
  }

  String _getSigningAlgo(SigningAlgoType? signingAlgoType) {
    switch(signingAlgoType) {
      case SigningAlgoType.ecc_secp256r1:
        return "ecc_secp256r1";
      case SigningAlgoType.rsa2048:
        return "rsa2048";
      case SigningAlgoType.rsa4096:
        return "rsa4096";
      default:
        return "rsa2048";
    }
  }
}