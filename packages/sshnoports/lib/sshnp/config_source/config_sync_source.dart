part of 'config_source.dart';

/// [ConfigSource] covariant from an [AtKey]
class ConfigSyncSource implements ConfigSource {
  late final AtKey atKey;
  late final AtClient atClient;

  SSHNPParams? _params;

  @override
  SSHNPParams get params => _params ?? SSHNPParams.empty();

  ConfigSyncSource._(this.atKey, this.atClient);

  factory ConfigSyncSource(String profileName, AtClient atClient) {
    AtKey atKey = profileNameToAtKey(profileName, sharedBy: atClient.getCurrentAtSign()!);
    print('sync src: $profileName, $atKey');
    return ConfigSyncSource._(atKey, atClient);
  }

  void _updateTimestamp() {
    atKey.metadata = Metadata()..updatedAt = DateTime.now();
  }

  @override
  Future<DateTime> getLastModified({bool refresh = true}) async {
    if (refresh) await atClient.get(atKey);
    return atKey.metadata?.updatedAt ?? DateTime(0);
  }

  @override
  Future<void> create(SSHNPParams params) => update(params);

  @override
  Future<SSHNPParams> read() async {
    print('called read for $atKey');
    var atValue = await atClient.get(atKey);
    print('done read');
    try {
      print("json: ${atValue.value}");
      _params = SSHNPParams.fromJson(atValue.value!);
    } catch (e) {
      _params = SSHNPParams.empty();
    }

    return params;
  }

  @override
  Future<void> update(SSHNPParams params) {
    _updateTimestamp();
    return atClient.put(atKey, params.toJson());
  }

  @override
  Future<void> delete() {
    return atClient.delete(atKey);
  }
}
