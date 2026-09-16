import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/language.dart';

class SettingsRepository {
  final AtClient? _atClient;

  const SettingsRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;
  AtKey get settingsAtKey =>
      AtKey.self('settings', namespace: Constants.namespace).build();

  Settings get defaultSettings => Settings(
    relayAtsign: RelayOptions.am.relayAtsign,
    viewLayout: PreferredViewLayout.minimal,
    overrideRelay: false,
    // set the default language to the device's language
    language: LanguageUtil.getLanguageFromLocale(Locale(Platform.localeName)),
  );

  Future<Settings?> getSettings() async {
    AtClient atClient = _client;
    try {
      var value = await atClient.get(
        settingsAtKey..sharedBy = atClient.getCurrentAtSign(),
      );
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
    AtClient atClient = _client;
    try {
      return await atClient.put(settingsAtKey, jsonEncode(settings.toJson()));
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSettings(Settings settings) async {
    AtClient atClient = _client;
    try {
      return await atClient.delete(
        settingsAtKey..sharedBy = atClient.getCurrentAtSign(),
      );
    } catch (_) {
      return false;
    }
  }
}
