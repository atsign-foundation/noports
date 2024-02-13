import 'dart:convert';

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
    await readProfilePrivateKeyManager(manager.profileNickname);
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
}
