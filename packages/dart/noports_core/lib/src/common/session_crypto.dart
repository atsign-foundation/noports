import 'dart:convert';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';

/// A fresh AES-256 key, base64 encoded.
String generateAes256Key() => AESKey.generate(32).key;

/// A fresh 16-byte initialisation vector.
InitialisationVector generateIv() => InitialisationVector.random(16);

/// A fresh 16-byte initialisation vector, base64 encoded.
String generateIvBase64() => base64Encode(generateIv().ivBytes);

/// Signs the UTF-8 bytes of [data] with RSA-2048 PKCS#1 v1.5 over SHA-256,
/// returning the signature base64 encoded.
///
/// [privateKey] is the base64 PKCS#8 form that `.atKeys` files and
/// [RsaKeyPair] hold. Throws [AtSigningException] for any key that is not a
/// 2048-bit RSA key.
String rsaSignString(String data, {required String privateKey}) =>
    base64Encode(
      RsaSignatureAlgo.rsa2048().signBytesSync(
        utf8.encode(data),
        secretKey: base64Decode(privateKey),
      ),
    );

/// Whether [signature] (base64) is an RSA-2048 PKCS#1 v1.5 signature over the
/// UTF-8 bytes of [data], made with the private half of [publicKey] (base64
/// X.509) using [hashing].
///
/// False, rather than a throw, for every shape of bad input: an unsupported
/// [hashing], undecodable base64, or a key that is not 2048-bit RSA.
Future<bool> rsaVerifyString(
  String data, {
  required String signature,
  required String publicKey,
  required HashingAlgoType hashing,
}) async {
  final RsaSignatureAlgo algo;
  final Uint8List signatureBytes, publicKeyBytes;
  try {
    algo = RsaSignatureAlgo.rsa2048(hashing: hashing);
    signatureBytes = base64Decode(signature);
    publicKeyBytes = base64Decode(publicKey);
  } on Exception {
    return false;
  }
  return algo.verifyBytes(
    utf8.encode(data),
    signature: signatureBytes,
    publicKey: publicKeyBytes,
  );
}

/// Encrypts the UTF-8 bytes of [plaintext] to the RSA [publicKey] (base64
/// X.509), returning the ciphertext base64 encoded.
String rsaEncryptString(String plaintext, {required String publicKey}) {
  final algo = RsaEncryptionAlgo()..atPublicKey = AtPublicKey.fromString(publicKey);
  return base64Encode(algo.encrypt(utf8.encode(plaintext)));
}

/// Decrypts [ciphertext] (base64) with the private half of [keyPair], returning
/// the plaintext decoded as UTF-8.
String rsaDecryptString(String ciphertext, {required RsaKeyPair keyPair}) =>
    utf8.decode(
      RsaEncryptionAlgo.fromKeyPair(keyPair).decrypt(base64Decode(ciphertext)),
    );

/// Encrypts the UTF-8 bytes of [plaintext] with AES-256 [key] (base64) and
/// [iv], returning the ciphertext base64 encoded.
Future<String> aesEncryptString(
  String plaintext, {
  required String key,
  required InitialisationVector iv,
}) async => base64Encode(
  await AESEncryptionAlgo(AESKey(key)).encrypt(utf8.encode(plaintext), iv: iv),
);

/// Decrypts [ciphertext] (base64) with AES-256 [key] (base64) and [iv],
/// returning the plaintext decoded as UTF-8.
Future<String> aesDecryptString(
  String ciphertext, {
  required String key,
  required InitialisationVector iv,
}) async => utf8.decode(
  await AESEncryptionAlgo(AESKey(key)).decrypt(base64Decode(ciphertext), iv: iv),
);
