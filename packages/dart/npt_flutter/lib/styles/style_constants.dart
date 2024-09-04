import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/sizes.dart';

import 'app_color.dart';

class StyleConstants {
  static ButtonStyle backButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColor.primaryColor,
    textStyle: const TextStyle(fontSize: Sizes.p18),
  );
}
