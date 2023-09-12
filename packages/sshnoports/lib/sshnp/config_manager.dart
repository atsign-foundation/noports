import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:sshnoports/sshnp/config_file_utils.dart';
import 'package:sshnoports/sshnp/config_source/config_source.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';

class ConfigManager {
  static const namespace = 'profiles.${SSHNPD.namespace}';

  final Map<String, ConfigFamilyManager> _configFamilyManagers = {};
  Map<String, ConfigFamilyManager> get managers => _configFamilyManagers;

  final Completer<bool> _initialized = Completer();
  Future<bool> get initialized => _initialized.future;

  final AtClient _atClient;

  ConfigManager(this._atClient, {bool useRemoteConfig = true, bool useLocalConfig = true}) {
    _init(useRemoteConfig: useRemoteConfig, useLocalConfig: useLocalConfig);
  }

  Future<void> _init({bool useRemoteConfig = true, bool useLocalConfig = true}) async {
    await Future.wait([
      if (useLocalConfig) _loadFiles(),
      if (useRemoteConfig) _loadKeys(),
    ]);
    print('loaded config');
    await Future.wait(managers.values.map((manager) {
      return Future.wait([
        manager._init(),
        // manager.syncToRemote(_atClient),
        // manager.syncToLocal(),
        // TOdo sync based on which is latest / more correct
      ]);
    }));
    print('synced config');
    _initialized.complete(true);
  }

  Future<void> _loadFiles() async {
    await createConfigDirectory();
    var profiles = await listProfilesFromDirectory();
    for (var fileName in profiles) {
      var profileName = configFileNameToProfileName(fileName);
      if (!_configFamilyManagers.containsKey(profileName)) {
        _configFamilyManagers[profileName] = ConfigFamilyManager(profileName);
      }
      _configFamilyManagers[profileName]!.sources.add(ConfigSource.file(profileName));
    }
  }

  Future<void> _loadKeys() async {
    var keys = await _atClient.getAtKeys(regex: namespace);
    for (var atKey in keys) {
      var profileName = atKeyToProfileName(atKey);
      print('load: $atKey, $profileName');
      if (!_configFamilyManagers.containsKey(profileName)) {
        _configFamilyManagers[profileName] = ConfigFamilyManager(profileName);
      }
      _configFamilyManagers[profileName]!.sources.add(ConfigSource.sync(profileName, _atClient));
    }
  }

  Future<ConfigFamilyManager> operator [](String key) async {
    _configFamilyManagers[key] ??= ConfigFamilyManager(key);
    await _configFamilyManagers[key]!._init();
    return _configFamilyManagers[key]!;
  }
}

class ConfigFamilyManager {
  final String profileName;
  final List<ConfigSource> sources = [];

  ConfigFamilyManager(this.profileName);

  final Completer<bool> initialized = Completer();
  bool _initCalled = false;

  late SSHNPParams _params;
  SSHNPParams get params => _params;

  Future<void> _init() async {
    print('called init for $profileName');
    if (_initCalled) return;
    _initCalled = true;

    await Future.wait(sources.map((s) => s.read()));
    print('done read for $profileName');
    var latestModified = DateTime(0);

    ConfigSource? latestSource;
    for (var source in sources) {
      var modified = await source.getLastModified(refresh: false);
      if (modified.isAfter(latestModified)) {
        latestModified = modified;
        latestSource = source;
      }
    }
    print('done getLastestSource for $profileName');

    _params = latestSource?.params ?? SSHNPParams.empty();
    initialized.complete(true);
  }

  Future<void> create(SSHNPParams params) async {
    await initialized.future;
    _params = params;
    await Future.wait(sources.map((s) => s.create(params)));
  }

  Future<void> update(SSHNPParams params) async {
    await initialized.future;
    _params = params;
    await Future.wait(sources.map((s) => s.update(params)));
  }

  Future<void> delete() async {
    if (!initialized.isCompleted) {
      await _init();
    }
    await Future.wait(sources.map((s) => s.delete()));
  }

  Future<void> syncToRemote(AtClient atClient) async {
    print('starting sync');
    await initialized.future;
    print('init sync local');
    var remotes = sources.whereType<ConfigSyncSource>();
    if (remotes.isNotEmpty) {
      await Future.wait(remotes.map((s) => s.update(params)));
      print('done sync refresh');
      return;
    }
    var source = ConfigSource.sync(profileName, atClient);
    await source.create(params);
    print('done sync');
    sources.add(source);
  }

  Future<void> syncToLocal() async {
    print('starting sync local');
    await initialized.future;
    print('init sync local');
    var locals = sources.whereType<ConfigFileSource>();
    if (locals.isNotEmpty) {
      await Future.wait(locals.map((s) => s.update(params)));
      print('done sync refresh local');
      return;
    }
    print('comp: $profileName, ${params.toJson()}');
    var source = ConfigSource.file(profileName);
    await source.create(params);
    print('done sync local');
    sources.add(source);
  }
}
