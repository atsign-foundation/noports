import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/private_key_manager.dart';

/// A repository for managing [PrivateKeyManager]s network requests.
class PrivateKeyManagerRepository {
  /// Writes a [PrivateKeyManager] to the device's secure storage.
  static Future<void> writePrivateKeyManager(PrivateKeyManager manager) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('com.atsign.sshnoports.ssh-${manager.nickname}', jsonEncode(manager.toMap()));
  }

  /// Reads a [PrivateKeyManager] from the device's secure storage.
  static Future<PrivateKeyManager> readPrivateKeyManager(String identifier) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('com.atsign.sshnoports.ssh-$identifier');
    if (data.isNull || data!.isEmpty) {
      return PrivateKeyManager.empty();
    } else {
      return PrivateKeyManager.fromJson(jsonDecode(data));
    }
  }

  /// Deletes a [PrivateKeyManager] from the device's secure storage.
  static Future<void> deletePrivateKeyManager(String identifier) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('com.atsign.sshnoports.ssh-$identifier');
  }

  /// Writes a list of [PrivateKeyManager] nicknames to the device's secure storage.
  static Future<void> writePrivateKeyManagerNicknames(
    List<String> identities,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('com.atsign.sshnoports.nicknames', identities);
  }

  /// Returns a list of [PrivateKeyManager] nickname from the device's secure storage.
  static Future<Iterable<String>> listPrivateKeyManagerNickname() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final decodedData = prefs.getStringList('com.atsign.sshnoports.nicknames');
    if (decodedData == null) {
      return [];
    } else {
      return decodedData;
    }
  }
}
