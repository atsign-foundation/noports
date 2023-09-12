import 'package:at_client/at_client.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';

class ConfigKeyRepository {
  static const String _keyPrefix = 'profile_';
  static const String _configNamespace = 'profiles.${SSHNPD.namespace}';

  static String toProfileName(AtKey atKey, {bool replaceSpaces = true}) {
    var profileName = atKey.key!.split('.').first;
    profileName = profileName.replaceFirst(_keyPrefix, '');
    if (replaceSpaces) profileName = profileName.replaceAll('_', ' ');
    return profileName;
  }

  static AtKey fromProfileName(String profileName, {String sharedBy = '', bool replaceSpaces = true}) {
    if (replaceSpaces) profileName = profileName.replaceAll(' ', '_');
    return AtKey.self(
      '$_keyPrefix$profileName',
      namespace: _configNamespace,
      sharedBy: sharedBy,
    ).build();
  }

  static Future<Iterable<String>> listProfiles(AtClient atClient) async {
    var keys = await atClient.getAtKeys(regex: _configNamespace);
    return keys.map((e) => toProfileName(e));
  }

  static Future<SSHNPParams> getParams(String profileName,
      {required AtClient atClient, GetRequestOptions? options}) async {
    AtKey key = fromProfileName(profileName);
    key.sharedBy = atClient.getCurrentAtSign()!;
    AtValue value = await atClient.get(key, getRequestOptions: options);
    if (value.value == null) return SSHNPParams.empty();
    return SSHNPParams.fromJson(value.value!);
  }

  static Future<void> putParams(SSHNPParams params, {required AtClient atClient, PutRequestOptions? options}) async {
    AtKey key = fromProfileName(params.profileName!);
    key.sharedBy = atClient.getCurrentAtSign()!;
    await atClient.put(key, params.toJson(), putRequestOptions: options);
  }

  static Future<void> deleteParams(String profileName,
      {required AtClient atClient, DeleteRequestOptions? options}) async {
    AtKey key = fromProfileName(profileName);
    key.sharedBy = atClient.getCurrentAtSign()!;
    await atClient.delete(key, deleteRequestOptions: options);
  }
}
