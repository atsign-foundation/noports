import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Constants {
  static String? get namespace => 'noports';
  // TODO: issue & secure API key properly
  static String? get appAPIKey => 'asdf';

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';

  static Map<String, String> getRootDomains(BuildContext context) {
    AppLocalizations strings = AppLocalizations.of(context)!;

    return {'root.atsign.org': strings.rootDomainDefault, 'vip.ve.atsign.zone': strings.rootDomainDemo};
  }
}
