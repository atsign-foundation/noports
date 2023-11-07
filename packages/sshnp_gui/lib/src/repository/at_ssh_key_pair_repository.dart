import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:noports_core/utils.dart';

class AtSSHKeyPairRepository {
  static Future<void> writeAtSSHKeyPair(AtSSHKeyPair atSSHKeyPair) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-${atSSHKeyPair.identifier}');

    await storage.write(jsonEncode(atSSHKeyPair.toJson));
  }

  static Future<AtSSHKeyPair?> readAtSSHKeyPair(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final data = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier').then(
          (value) => value.read(),
        );
    if (data.isNull || data!.isEmpty) {
      return null;
    } else {
      return AtSSHKeyPair.fromJson(jsonDecode(data));
    }
  }

  static Future<void> deleteAtSSHKeyPair(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier');
    await storage.delete();
  }

  static Future<Iterable<String>> listAtSSHKeyPairIdentities() async {
    final decodedData =
        await BiometricStorage().getStorage('com.atsign.sshnoports.nicknames').then((value) => value.read());
    return jsonDecode(decodedData!);
  }

  static Future<void> writeAtSSHKeyPairIdentities(
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
