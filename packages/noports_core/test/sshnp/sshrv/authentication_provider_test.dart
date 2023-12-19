import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/sshrv/auth_provider.dart';
import 'package:noports_core/src/sshrvd/signature_verifying_socket_authenticator.dart';
import 'package:test/test.dart';

void main() {

  String testEncryptionPrivateKey =
      'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCYquy7G6jcoBn4XzGekERg9OgnOxGmLAWYxgNUqWE7kHVsHrc9RRjQ0LCr9FdKo3bwjtNvO/qeoCNGDMpS6b6uww0mqVXAZk//bqQPu+jzZRgOW7Kogqan24Ona1aZHnfprvepKX2fEo1j7tzCsVafWsymuJa1ozrumwx5ecwrj/B0rXq1vnkJQMq4ekTbL29O1O2fmfnZovnSOy22MUHEFf6HWGRQc6muAt+nCqweSdu4Q0cv2ZMKw4XPWeWapHNrIKC1Po84J64OuPauhXLOPWT+8PbmsIwgbYP25WQ9DLdCLVaL9IRi87N5rNgT+YHe4EZv6W2YYMoPn1JzDfW5AgMBAAECggEAVYXC0dpf0SAbDEj/ee0lcQ8hEgEEFQuqIvgiG4Y7Quvc67GVQsx3Z1rQ7bMWR2ilE4NfLHv0HHJm8DHwEVyCBlKcBmFr+TkXbWcknu/MQrUKMdjqj32JMJVG/j2iKGqqEA2FDY2Bot/4ttezcZl4hhKOfIMBYkVLmSjgZxh06J1/MO0TFRbbsNNhCWmV0SzwxmS6O21/4ca8IbnD59KQbYAY4q60WcswkLm2VKNngOOggFHRIBQVu0KLvF6jr9IWHkR/b+rKOrR4r04bdIKCVf7mtWKc6lKoqKYJeXiK1WPPOuvZKpyTGNIYr99uGnCQ6Swj67T/btz194P6x+dpxQKBgQDKFy8bxkKeXPvUAVNgPSA7tndvinrfm4Q0UTtbovAtiAegTAJfAC9Kn3GkUFHMe9hPIaGFlfv0BncIZLWyYOOrfrL4FoxFpogIqYpROeu6QvUuGDMOo/qqBqn3s77Zkq5FGjAj5FgIqVmCP4XwJ9lOksSvGpPoFz507hTu7QskswKBgQDBZKOdFbJAjP62LoS78g7TSeT7C3AXgd9jM8RZs/xYKIAKE3st/2BdjSOveo0jTG47+U3+Tws7oMyMmO69u/RhsmF4z2Fg6Th6S/D+HrNDmm0BkBQ865mEY2TahhdfjUewTTCC+T00x2TBLZmJDjZPMO8BTZ2SljX0rVQttOVp4wKBgDTWcPOzF5HuP82DdzgvYzEZmQqpy0yRjbRcFMf1xxQwf8XyeaA7HSJGo+DRO0Hak4jFA0U5HMIFurOQGU2FNaGOI97njk9bpi+VnFt2aGKvxQkDPL40M4Km8WOZNGoQhs38dd+8gSPqm0OJtkw/LvrzNseNjGRfR24tHX4GriYvAoGAKBsNzyrLr5VN0UwuXKejKXAem21Qzp8xS2pV4uBviXzEqNJHbk+SlXQKnX6FvHdCOQ/He+C6jKAZK2Mfx5st4ADVM++V2zoia0JKdPi65l8lEfjmKYgWax0Nsj+yoy8yWb54PAEiD0r2exVQzNp0qtGUDyogbmDWSaqUVXI5TU8CgYB8vuHUsTx4ibazsmth/TztlAhQMk3TNmi5/MoCNuzJNf3WXwx11iKiIwb+zQjyk4Vbhs54GTTx4FQcjtHHRg9B/XA64zckKIGI/5BLpT/LuM67MeVS73uD7J6jy6BdmFtbz3ChRTA4+x7Y8AGtARFVPIENL1cAY1nisb4cT3vwQg==';

  String testEncryptionPublicKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmKrsuxuo3KAZ+F8xnpBEYPToJzsRpiwFmMYDVKlhO5B1bB63PUUY0NCwq/RXSqN28I7Tbzv6nqAjRgzKUum+rsMNJqlVwGZP/26kD7vo82UYDluyqIKmp9uDp2tWmR536a73qSl9nxKNY+7cwrFWn1rMpriWtaM67psMeXnMK4/wdK16tb55CUDKuHpE2y9vTtTtn5n52aL50jsttjFBxBX+h1hkUHOprgLfpwqsHknbuENHL9mTCsOFz1nlmqRzayCgtT6POCeuDrj2roVyzj1k/vD25rCMIG2D9uVkPQy3Qi1Wi/SEYvOzeazYE/mB3uBGb+ltmGDKD59Scw31uQIDAQAB';

  test('Test json signinging and verification', () {

    var provider = SignatureAuthenticator('hello', testEncryptionPrivateKey);
    var signedData = provider.sign('hello');
    print(signedData);
    SignatureAuthVerifier sa = SignatureAuthVerifier(testEncryptionPublicKey , 'hello');
    List<int> list = utf8.encode(signedData);
    Uint8List data = Uint8List.fromList(list);

    bool authenticated;
    Uint8List? unused;

    (authenticated, unused) = sa.onData(data, MockSocket());
    expect(authenticated, true);
    expect(unused, null);
  });
}

class MockSocket extends Mock implements Socket {}