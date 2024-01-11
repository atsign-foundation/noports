import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:biometric_storage/biometric_storage.dart';

import '../application/private_key_manager.dart';

/// A repository for managing [PrivateKeyManager]s network requests.
class PrivateKeyManagerRepository {
  /// Writes a [PrivateKeyManager] to the device's secure storage.
  static Future<void> writePrivateKeyManager(PrivateKeyManager manager) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-${manager.nickname}');

    await storage.write(jsonEncode(manager.toMap()));
  }

  /// Reads a [PrivateKeyManager] from the device's secure storage.
  static Future<PrivateKeyManager?> readPrivateKeyManager(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final data = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier').then(
          (value) => value.read(),
        );
    if (data.isNull || data!.isEmpty) {
      return null;
    } else {
      return PrivateKeyManager.fromJson(jsonDecode(data));
    }
  }

  /// Deletes a [PrivateKeyManager] from the device's secure storage.
  static Future<void> deletePrivateKeyManager(String identifier) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.ssh-$identifier');
    await storage.delete();
  }

  /// Writes a list of [PrivateKeyManager] nicknames to the device's secure storage.
  static Future<void> writePrivateKeyManagerNicknames(
    List<String> identities,
  ) async {
    BiometricStorage biometricStorage = BiometricStorage();
    final storage = await biometricStorage.getStorage('com.atsign.sshnoports.nicknames');

    await storage.write(jsonEncode(identities));
  }

  /// Returns a list of [PrivateKeyManager] nickname from the device's secure storage.
  static Future<Iterable<String>> listPrivateKeyManagerNickname() async {
    final decodedData =
        await BiometricStorage().getStorage('com.atsign.sshnoports.nicknames').then((value) => value.read());
    if (decodedData == null) {
      return [];
    } else {
      return [...jsonDecode(decodedData)];
    }
  }
}
