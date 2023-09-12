part of 'config_source.dart';

/// [ConfigSource] covariant from an [AtKey]
class ConfigSyncSource implements ConfigSource {
  late final AtKey atKey;
  late final AtClient atClient;

  SSHNPParams? _params;

  @override
  SSHNPParams get params => _params ?? SSHNPParams.empty();

  ConfigSyncSource._(this.atKey, this.atClient);

  factory ConfigSyncSource.synced(String profileName, {AtClient? atClient}) {
    AtKey atKey = AtKey.self(
      'profile_$profileName',
      namespace: SSHNPD.namespace,
    ).build();

    atClient ??= AtClientManager.getInstance().atClient;
    return ConfigSyncSource._(atKey, atClient);
  }

  void _updateTimestamp() {
    atKey.metadata = Metadata()..updatedAt = DateTime.now();
  }

  @override
  DateTime get lastModified => atKey.metadata?.updatedAt ?? DateTime(0);

  @override
  Future<void> create(SSHNPParams params) => update(params);

  @override
  Future<SSHNPParams> read() async {
    var atValue = await atClient.get(atKey, getRequestOptions: GetRequestOptions()..bypassCache);

    try {
      _params = SSHNPParams.fromJson(atValue.value);
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
  Future<void> delete(SSHNPParams params) {
    return atClient.delete(atKey, deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true);
  }
}
