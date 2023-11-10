import 'dart:convert';
import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:biometric_storage/biometric_storage.dart';

import '../application/at_ssh_key_pair_manager.dart';

class AtSshKeyPairManagerRepository {
  static Future<void> writeAtSshKeyPair(AtSshKeyPairManager manager) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-${manager.nickname}');

    await storage.write(jsonEncode(manager.toMap()));
    final data = await readAtSshKeyPair(manager.nickname);
    if (data == null) {
      log('no data');
    } else {
      log('nickName: ${data.nickname}');
      log('passPhrase: ${data.passPhrase}');
      log('file: ${data.privateKeyFileName}');
      log('content: ${data.content}');
    }
  }

  static Future<AtSshKeyPairManager?> readAtSshKeyPair(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final data = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier').then(
          (value) => value.read(),
        );
    if (data.isNull || data!.isEmpty) {
      return null;
    } else {
      return AtSshKeyPairManager.fromJson(jsonDecode(data));
    }
  }

  static Future<void> deleteAtSshKeyPair(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier');
    await storage.delete();
  }

  static Future<Iterable<String>> listAtSshKeyPairIdentities() async {
    final decodedData =
        await BiometricStorage().getStorage('com.atsign.sshnoports.nicknames').then((value) => value.read());
    return [...jsonDecode(decodedData!)];
  }

  static Future<void> writeAtSshKeyPairIdentities(
    List<String> identities,
  ) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.nicknames');

    await storage.write(jsonEncode(identities));
  }

  // static Future<void> deleteParams(String profileName,
  //     {required AtClient atClient, DeleteRequestOptions? options}) async {
  //   AtKey key = fromProfileName(profileName);
  //   key.sharedBy = atClient.getCurrentAtSign()!;
  //   await atClient.delete(key, deleteRequestOptions: options);
  // }
}
