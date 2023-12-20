class ProfilePrivateKeyManager {
  final String profileNickname;
  final String privateKeyNickname;

  ProfilePrivateKeyManager({
    required this.profileNickname,
    required this.privateKeyNickname,
  });

  ProfilePrivateKeyManager.empty({
    this.profileNickname = '',
    this.privateKeyNickname = '',
  });

  ProfilePrivateKeyManager.fromJson(Map<String, dynamic> json)
      : profileNickname = json['nickName'],
        privateKeyNickname = json['privateKeyNickname'];

  Map<String, String?> toMap() {
    return {
      'nickName': profileNickname,
      'privateKeyNickname': privateKeyNickname,
    };
  }

  String get identifier => '$profileNickname-$privateKeyNickname';
}
