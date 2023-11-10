import 'package:noports_core/utils.dart';

class AtSshKeyPairManager {
  final String nickname;
  final String? passPhrase;
  final String content;
  final String privateKeyFileName;

  AtSshKeyPairManager({
    required this.nickname,
    this.passPhrase,
    required this.content,
    required this.privateKeyFileName,
  });

  AtSshKeyPairManager.empty({
    this.nickname = '',
    this.passPhrase = '',
    this.content = '',
    this.privateKeyFileName = '',
  });

  AtSshKeyPairManager.fromJson(Map<String, dynamic> json)
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
