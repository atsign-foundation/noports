import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;

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

  static String? get namespace => 'noports';

  static Future<String?> get appAPIKey async {
    await loadDotenv();
    return dotenv.env["APP_API_KEY"];
  }

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';

  static Map<String, String> getRootDomains(BuildContext context) {
    AppLocalizations strings = AppLocalizations.of(context)!;

    return {'root.atsign.org': strings.rootDomainDefault, 'vip.ve.atsign.zone': strings.rootDomainDemo};
  }

  static const kWindowsMinWindowSize = Size(1053, 691);
}
