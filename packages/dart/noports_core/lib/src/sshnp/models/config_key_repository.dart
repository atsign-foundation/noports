import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/models/sshnp_params.dart';

class ConfigKeyRepository {
  @visibleForTesting
  static const String keyPrefix = 'profile_';

  @visibleForTesting
  static const String configNamespace = 'profiles.${DefaultArgs.namespace}';

  static String toProfileName(AtKey atKey, {bool replaceSpaces = true}) {
    var profileName = atKey.key.split('.').first;
    profileName = profileName.replaceFirst(keyPrefix, '');
    if (replaceSpaces) profileName = profileName.replaceAll('_', ' ');
    return profileName;
  }

  static AtKey fromProfileName(String profileName,
      {String sharedBy = '', bool replaceSpaces = true}) {
    if (replaceSpaces) profileName = profileName.replaceAll(' ', '_');
    return AtKey.self(
      '$keyPrefix$profileName',
      namespace: configNamespace,
      sharedBy: sharedBy,
    ).build();
  }

  static Future<Iterable<String>> listProfiles(AtClient atClient) async {
    var keys = await atClient.getAtKeys(regex: configNamespace);
    return keys.map((e) => toProfileName(e));
  }

  static Future<SshnpParams> getParams(String profileName,
      {required AtClient atClient, GetRequestOptions? options}) async {
    AtKey key = fromProfileName(profileName);
    key.sharedBy = atClient.getCurrentAtSign()!;
    AtValue value = await atClient.get(key, getRequestOptions: options);
    if (value.value == null) return SshnpParams.empty();
    return SshnpParams.fromJson(value.value!);
  }

  static Future<void> putParams(SshnpParams params,
      {required AtClient atClient, PutRequestOptions? options}) async {
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
