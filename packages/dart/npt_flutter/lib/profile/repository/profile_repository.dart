import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/profile/profile.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Profile?> getProfile(String id) async {
    // TODO remove me later
    if (id == "npfs") {
      return const Profile(
        "npfs",
        displayName: "npfs",
        sshnpdAtsign: '@xchan',
        deviceName: 'npfs',
        remotePort: 80,
        localPort: 8080,
      );
    }

    AtClient atClient = AtClientManager.getInstance().atClient;
    AtKey key = ProfileUtil.getAtKeyForProfileId(id);
    try {
      var value = await atClient.get(key);
      var profile = Profile.fromJson(jsonDecode(value.value));
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<bool> putProfile(Profile profile) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    AtKey key = ProfileUtil.getAtKeyForProfile(profile);

    try {
      return await atClient.put(key, jsonEncode(profile.toJson()));
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProfile(Profile profile) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    AtKey key = ProfileUtil.getAtKeyForProfile(profile);

    try {
      return await atClient.delete(key);
    } catch (_) {
      return false;
    }
  }
}
