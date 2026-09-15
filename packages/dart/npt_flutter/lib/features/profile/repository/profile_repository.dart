import 'dart:convert';

import 'package:at_client/at_client.dart';
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
    List<String> keyStrs;
    try {
      keyStrs = await atClient.getKeys(
        regex: '.${Uuid.profilesSubNamespace}.$namespace',
        useRemoteAtServer: true,
      );
    } catch (e) {
      App.log('[ERROR] getProfileUuids failed: $e'.loggable);
      keyStrs = [];
    }
    return keyStrs.map((keyStr) {
      final atKey = AtKey.fromString(keyStr);
      return atKey.key.substring(
        0,
        atKey.key.indexOf('.${Uuid.profilesSubNamespace}'),
      );
    });
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
      final GetRequestOptions gro = GetRequestOptions()
        ..useRemoteAtServer = true;
      var value = await atClient.get(key, getRequestOptions: gro);
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
      final PutRequestOptions pro = PutRequestOptions()
        ..useRemoteAtServer = true;
      return await atClient.put(
        key,
        jsonEncode(profile.toJson()),
        putRequestOptions: pro,
      );
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
      final DeleteRequestOptions dro = DeleteRequestOptions()
        ..useRemoteAtServer = true;
      return await atClient.delete(key, deleteRequestOptions: dro);
    } catch (e) {
      App.log('[ERROR] deleteProfile($uuid) failed: $e'.loggable);
      return false;
    }
  }
}
