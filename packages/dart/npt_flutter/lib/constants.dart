class Constants {
  static const rootDomain = 'root.atsign.org';
  static String? get namespace => 'noports';
  // TODO: issue & secure API key properly
  static String? get appAPIKey => 'asdf';

  static const pngIcon = 'assets/noports-icon64.png';
  static const icoIcon = 'assets/noports-icon64.ico';

  static const Map<String, String> defaultRelayOptions = {
    "@rv_am": "Los Angeles",
    "@rv_eu": "London",
    "@rv_ap": "Singapore",
  };

  static const languages = ['English', 'Spanish', 'Br portuguese', 'Mandarin', 'Cantonese'];
}
