import 'dart:async' show FutureOr;
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:npt_flutter/localization/app_localizations.dart';

typedef RootDomainMetadata = ({
  dynamic description,
  String? registrarUrl,
  String? apiKey,
});
typedef RootDomainMap = Map<String, RootDomainMetadata>;

typedef ResolvedRootDomainMetadata = ({
  String description,
  String? registrarUrl,
  FutureOr<String?> apiKey,
});
typedef ResolvedRootDomainMap = Map<String, ResolvedRootDomainMetadata>;

class Constants {
  // Environment
  static bool dotenvLoaded = false;
  static Future<void> loadDotenv() async {
    if (dotenvLoaded) return;
    try {
      await dotenv.load();
      dotenvLoaded = true;
    } catch (e) {
      log(".env file failed to load");
      dotenvLoaded = false;
    }
  }

  static String? get namespace => 'noports';

  static Future<String?> get appAPIKey async {
    await loadDotenv();
    return dotenv.env["APP_API_KEY"];
  }

  static Future<String?> _getApiKey(String? registrarUrl) async {
    if (registrarUrl == null) return null;
    await loadDotenv();
    String key = "API_KEY_${registrarUrl.toUpperCase().replaceAll(".", "_")}";
    return dotenv.env[key];
  }

  // Root Domain configuration

  // description may be a String or String Function(BuildContext)
  static final RootDomainMap _rootDomainMap = {};

  static void registerDefaultRootDomains() {
    registerRootDomain('root.atsign.org', (
      description: (BuildContext context) =>
          AppLocalizations.of(context)!.rootDomainDefault,
      registrarUrl: "my.atsign.com",
      apiKey: null,
    ));
    registerRootDomain('vip.ve.atsign.zone', (
      description: (BuildContext context) =>
          AppLocalizations.of(context)!.rootDomainDemo,
      registrarUrl: null,
      apiKey: null, // injected via .env file
    ));
  }

  static void registerRootDomain(
      String rootDomain, RootDomainMetadata metadata) {
    _rootDomainMap[rootDomain] = metadata;
  }

  static bool rootDomainsIsEmpty() => _rootDomainMap.isEmpty;
  static ResolvedRootDomainMap getRootDomains(BuildContext context) {
    return _rootDomainMap.map((k, v) {
      late String desc;
      var reg = v.registrarUrl;
      var api = v.apiKey ?? _getApiKey(reg);
      if (v.description is String Function(BuildContext)) {
        desc = v.description.call(context);
      } else {
        desc = v.description as String;
      }
      return MapEntry(
        k,
        (description: desc, registrarUrl: reg, apiKey: api)
            as ResolvedRootDomainMetadata,
      );
    });
  }

  static const kWindowsMinWindowSize = Size(1053, 691);

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';
  static const authenticatorMockup = 'assets/authenticator-mockup.png';
  static const authenticatorApprovalMockup =
      'assets/authenticator-approval-mockup.png';
}
