import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/uuid.dart';

class ProfileRepository {
  final Map<String, Profile> _profileCache = {};

  final AtClient? _atClient;

  /// [AtClient] added for dependency injection during testing. Do not use this in production code.
  /// Leave as null since [AtClientManager.getInstance().atClient] is used internally in production.
  ProfileRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  Future<Iterable<String>?> getProfileUuids() async {
    AtClient atClient = _client;

    String namespace = Constants.namespace ?? '';
    List<AtKey> keys;
    try {
      keys = await atClient.getAtKeys(
        regex: '.${Uuid.profilesSubNamespace}.$namespace',
      );
    } catch (e) {
      App.log('[ERROR] getProfileUuids failed: $e'.loggable);
      keys = [];
    }
    return keys.map(
      (key) => key.key.substring(
        0,
        key.key.indexOf('.${Uuid.profilesSubNamespace}'),
      ),
    );
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

    AtClient atClient = _client;
    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    AtKey key = Uuid(uuid).toProfileAtKey(sharedBy: atsign);
    try {
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

    AtClient atClient = _client;
    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    AtKey key = Uuid(profile.uuid).toProfileAtKey(sharedBy: atsign);

    try {
      return await atClient.put(key, jsonEncode(profile.toJson()));
    } catch (e) {
      App.log('[ERROR] putProfile(${profile.uuid}) failed: $e'.loggable);
      return false;
    }
  }

  Future<bool> deleteProfile(String uuid) async {
    _profileCache.remove(uuid);
    AtClient atClient = _client;
    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    AtKey key = Uuid(uuid).toProfileAtKey(sharedBy: atsign);

    try {
      return await atClient.delete(key);
    } catch (e) {
      App.log('[ERROR] deleteProfile($uuid) failed: $e'.loggable);
      return false;
    }
  }
}
