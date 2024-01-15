import 'dart:convert';
import 'dart:developer';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/profile_private_key_manager.dart';

/// A repository for managing [ProfilePrivateKeyManager]s network requests.
class ProfilePrivateKeyManagerRepository {
  static const _profilePrivateKeyManager = 'com.atsign.sshnoports.profile-private-key-manager';

  /// Writes a [ProfilePrivateKeyManager] to the device's secure storage.
  static Future<void> writeProfilePrivateKeyManager(ProfilePrivateKeyManager manager) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_profilePrivateKeyManager-${manager.profileNickname}', jsonEncode(manager.toMap()));
    final data = await readProfilePrivateKeyManager(manager.profileNickname);
    // TODO: Remove this log after testing
    if (data == null) {
      log('no data');
    } else {
      log('Profile nickname: ${data.profileNickname}');
      log('Private Key nickname: ${data.privateKeyNickname}');
    }
  }

  /// Reads a [ProfilePrivateKeyManager] from the device's secure storage.
  static Future<ProfilePrivateKeyManager> readProfilePrivateKeyManager(String identifier) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_profilePrivateKeyManager-$identifier');
    if (data.isNull || data!.isEmpty) {
      return ProfilePrivateKeyManager.empty();
    } else {
      return ProfilePrivateKeyManager.fromJson(jsonDecode(data));
    }
  }

  /// Deletes a [ProfilePrivateKeyManager] from the device's secure storage.
  static Future<void> deleteProfilePrivateKeyManager(String identifier) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('$_profilePrivateKeyManager-$identifier');
  }

  // TODO: Remove this after testing

  /// Writes a list of [ProfilePrivateKeyManager] nicknames to the device's secure storage.
  // static Future<void> writeProfilePrivateKeyManagerNicknames(
  //   List<String> identities,
  // ) async {
  //   BiometricStorage biometricStorage = BiometricStorage();
  //   final storage = await biometricStorage.getStorage('$_profilePrivateKeyManager-nicknames');

  //   await storage.write(jsonEncode(identities));
  // }

  /// Returns a list of [ProfilePrivateKeyManager] nickname from the device's secure storage.
  // static Future<Iterable<String>> listProfilePrivateKeyManagerNickname() async {
  //   final decodedData =
  //       await BiometricStorage().getStorage('$_profilePrivateKeyManager-nicknames').then((value) => value.read());

  //   if (decodedData == null) {
  //     return [];
  //   } else {
  //     return [...jsonDecode(decodedData)];
  //   }
  // }
}
