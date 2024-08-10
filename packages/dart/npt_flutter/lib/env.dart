import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static const rootDomain = 'root.atsign.org';
  static String? get namespace => dotenv.env['NAMESPACE'];
  static String? get appAPIKey => dotenv.env['API_KEY'];

  static const List<String> defaultRelayOptions = [
    "@rv_am",
    "@rv_eu",
    "@rv_ap",
  ];

  // Languages
  // English
  // Spanish
  // Br portuguese
  // Mandarin
  // Cantonese
}
