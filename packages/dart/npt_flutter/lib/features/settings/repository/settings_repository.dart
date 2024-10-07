import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/settings/settings.dart';

class SettingsRepository {
  const SettingsRepository();
  AtKey get settingsAtKey => AtKey.self('settings', namespace: Constants.namespace).build();

  Settings get defaultSettings => Settings(
        relayAtsign: RelayOptions.am.relayAtsign,
        viewLayout: PreferredViewLayout.minimal,
        overrideRelay: false,
      );

  Future<Settings?> getSettings() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    try {
      var value = await atClient.get(settingsAtKey..sharedBy = atClient.getCurrentAtSign());
      if (value.value == null) {
        // No settings saved, so use the defaults
        return defaultSettings;
      }
      var settings = Settings.fromJson(jsonDecode(value.value));
      return settings;
    } catch (_) {
      return null;
    }
  }

  Future<bool> putSettings(Settings settings) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    try {
      return await atClient.put(settingsAtKey, jsonEncode(settings.toJson()));
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSettings(Settings settings) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    try {
      return await atClient.delete(settingsAtKey..sharedBy = atClient.getCurrentAtSign());
    } catch (_) {
      return false;
    }
  }
}
