import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_builders.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:npt_mobile_flutter/util/uuid.dart';

class ProfileRepository {
  final Map<String, Profile> _profileCache = {};

  final AtClient? _atClient;

  /// [AtClient] added for dependency injection during testing. Do not use this in production code.
  /// Leave as null since [AtClientManager.getInstance().atClient] is used internally in production.
  ProfileRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  /// Fetches profile UUIDs from the remote secondary server directly.
  /// This bypasses local cache and sync, useful for initial load after APKAM enrollment.
  Future<Iterable<String>?> getProfileUuidsFromRemote() async {
    AtClient atClient = _client;
    String namespace = Constants.namespace;

    try {
      App.log(
        '[ProfileRepo] Fetching profile UUIDs from remote secondary'.loggable,
      );

      App.log(
        '[ProfileRepo] Current atSign: ${atClient.getCurrentAtSign()}'.loggable,
      );

      final remoteSecondary = atClient.getRemoteSecondary();
      if (remoteSecondary == null) {
        App.log('[ProfileRepo] ERROR: No remote secondary available'.loggable);
        return [];
      }

      App.log('[ProfileRepo] Remote secondary is available'.loggable);

      // Build scan command to query remote secondary directly
      var builder = ScanVerbBuilder()
        ..regex = '.${Uuid.profilesSubNamespace}.$namespace'
        ..auth = true;

      App.log(
        '[ProfileRepo] Executing scan with regex: .${Uuid.profilesSubNamespace}.$namespace'
            .loggable,
      );

      var scanResult = await remoteSecondary.executeVerb(builder);

      App.log('[ProfileRepo] Remote scan result: $scanResult'.loggable);

      if (scanResult.isEmpty) {
        App.log('[ProfileRepo] Remote scan returned empty'.loggable);
        return [];
      }

      // Parse the scan result
      scanResult = scanResult.replaceFirst('data:', '');
      if (scanResult.isEmpty) {
        App.log(
          '[ProfileRepo] Remote scan data is empty after parsing'.loggable,
        );
        return [];
      }

      // Decode the JSON array of key strings
      List<String> keyStrings = List<String>.from(jsonDecode(scanResult));
      App.log(
        '[ProfileRepo] Found ${keyStrings.length} keys from remote'.loggable,
      );

      // Extract UUIDs from key strings
      final uuids = keyStrings.map((keyStr) {
        // Key format from scan: "uuid.profiles.noports@atsign" or "uuid.profiles.noports"
        // Remove the @atsign suffix if present
        final keyWithoutAtsign = keyStr.split('@').first;
        // Extract just the uuid part (before first dot)
        var parts = keyWithoutAtsign.split('.');
        final uuid = parts[0];
        App.log('[ProfileRepo] Parsed key "$keyStr" -> UUID "$uuid"'.loggable);
        return uuid;
      }).toList();

      App.log('[ProfileRepo] Extracted ${uuids.length} UUIDs: $uuids'.loggable);
      return uuids;
    } catch (e, st) {
      App.log('[ERROR] getProfileUuidsFromRemote failed: $e'.loggable);
      App.log('[ERROR] Stack trace: $st'.loggable);
      return [];
    }
  }

  Future<Iterable<String>?> getProfileUuids({bool preferRemote = false}) async {
    // If preferRemote is true, try remote first, then fall back to local
    if (preferRemote) {
      try {
        App.log('[ProfileRepo] Attempting remote fetch first'.loggable);
        var remoteUuids = await getProfileUuidsFromRemote();
        if (remoteUuids != null) {
          App.log(
            '[ProfileRepo] Remote fetch returned ${remoteUuids.length} UUIDs'
                .loggable,
          );
          // Return even if empty - empty is a valid result meaning no profiles exist
          return remoteUuids;
        }
        App.log(
          '[ProfileRepo] Remote fetch returned null, falling back to local'
              .loggable,
        );
      } catch (e) {
        App.log(
          '[WARN] Remote fetch failed, falling back to local: $e'.loggable,
        );
      }
    }

    App.log('[ProfileRepo] Fetching from local storage'.loggable);
    AtClient atClient = _client;

    String namespace = Constants.namespace;
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
    String? atSign = atClient.getCurrentAtSign();
    AtKey key = Uuid(uuid).toProfileAtKey(sharedBy: atSign);

    try {
      // Try local keystore first
      var value = await atClient.get(key);
      var profile = Profile.fromJson(jsonDecode(value.value));
      _profileCache[uuid] = profile;
      App.log(
        '[ProfileRepo] Loaded profile $uuid from local keystore'.loggable,
      );
      return profile;
    } catch (localError) {
      App.log(
        '[ProfileRepo] Local fetch for $uuid failed: $localError'.loggable,
      );

      // If local fails (e.g., after APKAM before sync), try remote secondary
      try {
        App.log(
          '[ProfileRepo] Attempting remote fetch for profile $uuid'.loggable,
        );
        final remoteSecondary = atClient.getRemoteSecondary();
        if (remoteSecondary == null) {
          App.log(
            '[ProfileRepo] No remote secondary available for $uuid'.loggable,
          );
          return null;
        }

        // For self-encrypted keys, use llookup (local lookup) on remote secondary
        // Regular lookup expects shared keys, but profile keys are self keys
        // llookup format: llookup:keyname.namespace@atsign
        final fullKeyName = '${key.key}.${key.namespace}${key.sharedBy}';
        App.log(
          '[ProfileRepo] Fetching self key $fullKeyName from remote'.loggable,
        );
        final llookupResult = await remoteSecondary.executeCommand(
          'llookup:$fullKeyName\n',
          auth: true,
        );

        if (llookupResult == null ||
            llookupResult.isEmpty ||
            llookupResult.contains('null')) {
          App.log(
            '[ProfileRepo] Remote llookup returned empty for $uuid'.loggable,
          );
          return null;
        }

        // Parse response - format is "data:<encrypted_value>"
        final encryptedData = llookupResult.replaceFirst('data:', '').trim();

        // Decrypt the value using the self-encryption key
        final localStorage = atClient.getLocalSecondary();
        final selfEncryptionKey = await localStorage?.getEncryptionSelfKey();

        if (selfEncryptionKey == null) {
          App.log(
            '[ProfileRepo] No self-encryption key available to decrypt profile $uuid'
                .loggable,
          );
          return null;
        }

        // Decrypt the encrypted value
        final decryptedValue = EncryptionUtil.decryptValue(
          encryptedData,
          selfEncryptionKey,
        );

        App.log('[ProfileRepo] Decrypted profile data for $uuid'.loggable);

        var profile = Profile.fromJson(jsonDecode(decryptedValue));
        _profileCache[uuid] = profile;
        App.log(
          '[ProfileRepo] Loaded profile $uuid from remote secondary'.loggable,
        );
        return profile;
      } catch (remoteError) {
        App.log(
          '[ERROR] getProfile($uuid) failed on both local and remote: $remoteError'
              .loggable,
        );
        return null;
      }
    }
  }

  Future<bool> putProfile(Profile profile) async {
    _profileCache[profile.uuid] = profile;

    AtClient atClient = _client;
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
    AtClient atClient = _client;
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
