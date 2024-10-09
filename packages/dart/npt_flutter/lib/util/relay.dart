import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class RelayUtil {
  static Map<String, String> getRelayDisplayNameMap(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return {
      "@rv_am": strings.rvAmDisplayName,
      "@rv_ap": strings.rvApDisplayName,
      "@rv_eu": strings.rvEuDisplayName,
    };
  }

  static List<String> getRelayAtsignList() {
    return ["@rv_am", "@rv_ap", "@rv_eu"];
  }
}
