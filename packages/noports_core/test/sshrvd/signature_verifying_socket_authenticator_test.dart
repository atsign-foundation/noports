import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/sshrvd/signature_verifying_socket_authenticator.dart';
import 'package:test/test.dart';

void main() {


  test('SignatureVerifyingSocketAuthenticator signature verification test', () {

    String pk = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmKrsuxuo3KAZ+F8xnpBEYPToJzsRpiwFmMYDVKlhO5B1bB63PUUY0NCwq/RXSqN28I7Tbzv6nqAjRgzKUum+rsMNJqlVwGZP/26kD7vo82UYDluyqIKmp9uDp2tWmR536a73qSl9nxKNY+7cwrFWn1rMpriWtaM67psMeXnMK4/wdK16tb55CUDKuHpE2y9vTtTtn5n52aL50jsttjFBxBX+h1hkUHOprgLfpwqsHknbuENHL9mTCsOFz1nlmqRzayCgtT6POCeuDrj2roVyzj1k/vD25rCMIG2D9uVkPQy3Qi1Wi/SEYvOzeazYE/mB3uBGb+ltmGDKD59Scw31uQIDAQAB';
    SignatureAuthVerifier sa = SignatureAuthVerifier(pk , 'hello');

    String source = '{"signature":"BeDvrOfOcKbA3CMwFsiWRUAjgdcfOc7kzDwdTODEfI94GZkZPGi6mo3c1e5BF88TnwZ1h4lMgecPZQpEkBPyHfa5Gk16VyZ/ddzyUfqhqW962ueneVpnfDzsLVVV6a6/Cz3PUojRGnLo/nAInlIE86REt3HYlkpWS9/IDIdamaPI1wuCkjOkUzFC3mfbV8kKABlaD6B50ePT6mS9+4EK5273UpKhQ5gWHons4mEw2iEqhXa4xmbdlr3JF2Al8FD8V+2itu+ecHwKA+uldxDIf5ckiPywdW65ti/QuVDQqtetky35ksePuSFSixbltjjMT+/7NTJ4ceFL5QtMCwKC3Q==","hashingAlgo":"sha256","signingAlgo":"rsa2048"}';
    List<int> list = utf8.encode(source);
    Uint8List data = Uint8List.fromList(list);

    bool authenticated;
    Uint8List? unused;

    (authenticated, unused) = sa.onData(data, MockSocket());
    expect(authenticated, true);
    expect(unused, null);

    source = '{"signature":"Invalid signature","hashingAlgo":"sha256","signingAlgo":"rsa2048"}';
    list = utf8.encode(source);
    data = Uint8List.fromList(list);

    expect(() => sa.onData(data, MockSocket()), throwsException);
  });
}

class MockSocket extends Mock implements Socket {}