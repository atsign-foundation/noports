import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static const rootDomain = 'root.atsign.org';
  static String? get namespace => dotenv.env['NAMESPACE'];
  static String? get appAPIKey => dotenv.env['API_KEY'];

  static const Map<String, String> defaultRelayOptions = {
    "@rv_am": "Los Angeles",
    "@rv_eu": "London",
    "@rv_ap": "Singapore",
  };
  // Languages
  // English
  // Spanish
  // Br portuguese
  // Mandarin
  // Cantonese
}
