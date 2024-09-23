class Constants {
  static const rootDomain = 'root.atsign.org';
  static String? get namespace => 'noports';
  // TODO: issue & secure API key properly
  static String? get appAPIKey => 'asdf';

  static const pngIconDark = 'assets/noports-icon64-dark.png';
  static const icoIconDark = 'assets/noports-icon64-dark.ico';
  static const pngIconLight = 'assets/noports-icon64-light.png';
  static const icoIconLight = 'assets/noports-icon64-light.ico';

  static const Map<String, String> defaultRelayOptions = {
    "@rv_am": "Los Angeles",
    "@rv_eu": "London",
    "@rv_ap": "Singapore",
  };

  static const languages = ['English', 'Spanish', 'Br portuguese', 'Mandarin', 'Cantonese'];
}
