import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileRepository {
  final Map<String, Profile> _profileCache = {};
  final Map<String, String?> _profileSharedByMap = {};

  Future<Iterable<String>?> getProfileUuids() async {
    _profileCache.clear();
    _profileSharedByMap.clear();
    AtClient atClient = AtClientManager.getInstance().atClient;

    String namespace = Constants.namespace ?? '';
    List<AtKey> keys;
    try {
      keys = await atClient.getAtKeys(
          regex: '.${Uuid.profilesSubNamespace}.$namespace');
    } catch (e) {
      App.log('[ERROR] getProfileUuids failed: $e'.loggable);
      keys = [];
    }

    for (final key in keys) {
      final ix = key.key.indexOf('.${Uuid.profilesSubNamespace}');
      if (ix >= 0) {
        final uuid = key.key.substring(0, ix);
        final sharedBy = key.sharedBy;
        _profileSharedByMap[uuid] = sharedBy;
      }
    }

    App.log('[DEBUG] _uuidMap = $_profileSharedByMap'.loggable);

    return _profileSharedByMap.keys;
  }

  Future<Iterable<Profile>> getProfiles(Iterable<String> uuids) {
    return Future.wait(uuids.map((uuid) => getProfile(uuid))).then(
      (profiles) =>
          profiles.where((profile) => profile != null).cast<Profile>(),
    );
  }

  Future<Profile?> getProfile(String uuid, {bool useCache = true}) async {
    if (useCache && _profileCache.containsKey(uuid)) {
      return _profileCache[uuid];
    }

    AtClient atClient = AtClientManager.getInstance().atClient;
    String ? sharedBy = _profileSharedByMap[uuid] ?? atClient.getCurrentAtSign();
    AtKey key = Uuid(uuid).toProfileAtKey(sharedBy: sharedBy);
    try {
      App.log('[DEBUG] loading profile $key'.loggable);
      var value = await atClient.get(key);
      var profile = Profile.fromJson(jsonDecode(value.value));
      _profileCache[uuid] = profile;
      return profile;
    } catch (e) {
      App.log('[ERROR] getProfile($uuid) failed: $e'.loggable);
      return null;
    }
  }

  Future<bool> putProfile(Profile profile) async {
    _profileCache[profile.uuid] = profile;

    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    AtKey key = Uuid(profile.uuid).toProfileAtKey(sharedBy: atSign);

    try {
      return await atClient.put(key, jsonEncode(profile.toJson()));
    } catch (e) {
      App.log('[ERROR] putProfile(${profile.uuid}) failed: $e'.loggable);
      return false;
    }
  }

  Future<bool> deleteProfile(String uuid) async {
    _profileCache.remove(uuid);
    _profileSharedByMap.remove(uuid);
    AtClient atClient = AtClientManager.getInstance().atClient;
    String? atSign = atClient.getCurrentAtSign();
    AtKey key = Uuid(uuid).toProfileAtKey(sharedBy: atSign);

    try {
      return await atClient.delete(key);
    } catch (e) {
      App.log('[ERROR] deleteProfile($uuid) failed: $e'.loggable);
      return false;
    }
  }
}
