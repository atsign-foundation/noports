import 'package:noports_core/utils.dart';

/// A model for connecting [PrivateKeyManager]'s with a profile.
class PrivateKeyManager {
  final String nickname;
  final String? passPhrase;
  final String content;
  final String privateKeyFileName;

  PrivateKeyManager({
    required this.nickname,
    this.passPhrase,
    required this.content,
    required this.privateKeyFileName,
  });

  PrivateKeyManager.empty({
    this.nickname = '',
    this.passPhrase = '',
    this.content = '',
    this.privateKeyFileName = '',
  });

  PrivateKeyManager.fromJson(Map<String, dynamic> json)
      : nickname = json['nickName'],
        passPhrase = json['passPhrase'],
        content = json['content'],
        privateKeyFileName = json['privateKeyFileName'];

  Map<String, String?> toMap() {
    return {
      'nickName': nickname,
      'passPhrase': passPhrase,
      'content': content,
      'privateKeyFileName': privateKeyFileName,
    };
  }

  AtSshKeyPair toAtSshKeyPair() {
    return AtSshKeyPair.fromPem(content, identifier: nickname, passphrase: passPhrase);
  }
}
