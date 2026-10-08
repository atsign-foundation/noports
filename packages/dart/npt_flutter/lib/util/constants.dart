import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:npt_flutter/localization/app_localizations.dart';

class Constants {
  static bool dotenvLoaded = false;
  static Future<void> loadDotenv() async {
    if (dotenvLoaded) return;
    try {
      await dotenv.load();
      dotenvLoaded = true;
    } catch (_) {
      dotenvLoaded = false;
    }
  }

  static String get favoriteKeyName => 'favorites';
  static String get namespace => 'noports';

  static Future<String?> get appAPIKey async {
    await loadDotenv();
    return dotenv.env["APP_API_KEY"];
  }

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';
  static const authenticatorMockup = 'assets/authenticator-mockup.png';
  static const authenticatorApprovalMockup =
      'assets/authenticator-approval-mockup.png';

  static Map<String, String> getRootDomains(BuildContext context) {
    AppLocalizations strings = AppLocalizations.of(context)!;

    return {
      'root.atsign.org': strings.rootDomainDefault,
      'vip.ve.atsign.zone': strings.rootDomainDemo,
    };
  }

  static const kWindowsMinWindowSize = Size(920, 600);
}

/// Constants for string that does not need to be localized.
class StringConst {
  static const String ampersand = '@';
  static const String atsignClient = 'atsign_client';
  static const String managementPortal = 'Management Portal';
  static const String monospace = 'monospace';
  static const String noPorts = 'NoPorts';
  static const String desktop = 'Desktop';
  static const String localhost = 'localhost';
}
