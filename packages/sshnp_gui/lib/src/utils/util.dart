import 'dart:io';

import 'package:flutter/foundation.dart';

class Util {
  static bool isMacos() {
    if (Platform.isMacOS && !kIsWeb) {
      return true;
    } else {
      return false;
    }
  }
}
