import 'dart:convert' show jsonDecode;
import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart'
    show AppLocalizations;

typedef RootMetadata = ({
  int port,
  LocalizedString description,
  String? registrarUrl,
  String? apiKey,
});
typedef RootMap = Map<String, RootMetadata>;

typedef LocalizedRootMetadata = ({
  int port,
  String description,
  String? registrarUrl,
  String? apiKey,
});
typedef LocalizedRootMap = Map<String, LocalizedRootMetadata>;
typedef LocalizedString = Map<String, String>;

class Constants {
  static const String namespace = 'noports';

  static final RootMap _rootMap = {};
  static initialize() {
    String rootsJson = const String.fromEnvironment(
      'roots',
      defaultValue: '{}',
    );
    Map<String, dynamic> roots = jsonDecode(rootsJson);
    for (var root in roots.entries) {
      var domain = root.key;
      if (root.value is! Map<String, dynamic>) {
        // ignore: avoid_print
        print("ERROR with configuration, root entry is not a JSON object");
        exit(1);
      }
      var port = root.value['port'] ?? 64;
      var descriptionJson = root.value['description'];
      var registrarUrl = root.value['registrarUrl'];
      var apiKey = root.value['api-key'];

      LocalizedString description = {};
      for (var desc in descriptionJson.entries) {
        if (desc.value is String) {
          description[desc.key] = desc.value;
        }
      }

      _rootMap[domain] = (
        port: (port is int && port > 0 && port < 65536) ? port : 64,
        description: description,
        registrarUrl: (registrarUrl is String) ? registrarUrl : null,
        apiKey: (apiKey is String) ? apiKey : null,
      );
    }
  }

  // Root Domain configuration
  static bool rootsIsEmpty() => _rootMap.isEmpty;
  static LocalizedRootMap getRoots(BuildContext context) {
    return _rootMap.map((k, v) {
      var locale = Locale(AppLocalizations.of(context)?.localeName ?? "en");
      var desc =
          v.description[locale.toString()] ?? // localized string
          v.description["en"] ?? // fallback to english
          k; // fallback to the domain if we couldn't find a description

  static String get favoriteKeyName => 'favorites';
  static String? get namespace => 'noports';

      return MapEntry(k, (
        port: v.port,
        description: desc,
        registrarUrl: v.registrarUrl,
        apiKey: v.apiKey,
      ));
    });
  }

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';
  static const authenticatorMockup = 'assets/authenticator-mockup.png';
  static const authenticatorApprovalMockup =
      'assets/authenticator-approval-mockup.png';

  static const kWindowsMinWindowSize = Size(1053, 691);
}
