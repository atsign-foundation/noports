import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';


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
class SignatureAuthenticator extends SocketAuthenticator {
  String sessionId;
  AtClient atClient;

  SignatureAuthenticator(this.sessionId, this.atClient);

  @override
  authenticate(Socket? socket) {
    // Sign and write to the socket
    String signedData = sign(sessionId);
    socket?.write(signedData);
  }

  String sign(String dataToSign) {
    return _signAndWrapAndJsonEncode(atClient, dataToSign);
  }

  String _signAndWrapAndJsonEncode(AtClient atClient, String dataToSign) {
    Map envelope = {};

    final AtSigningInput signingInput = AtSigningInput(dataToSign)
      ..signingMode = AtSigningMode.data;
    final AtSigningResult sr = atClient.atChops!.sign(signingInput);

    final String signature = sr.result.toString();
    envelope['signature'] = signature;
    envelope['hashingAlgo'] = sr.atSigningMetaData.hashingAlgoType!.name;
    envelope['signingAlgo'] = sr.atSigningMetaData.signingAlgoType!.name;
    return jsonEncode(envelope);
  }
}