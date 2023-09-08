import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utility/platform_utility/default_platform_utility.dart';

import 'package:sshnp_gui/src/utility/platform_utility/macos_utility.dart';

abstract class PlatformUtility {
  bool isPlatform();
  FutureOr<void> configurePlatform();
  Widget get app;

  static const _platforms = [
    MacosUtility(),
  ];

  factory PlatformUtility.current() {
    for (var platform in _platforms) {
      if (platform.isPlatform()) {
        return platform;
      }
    }
    return const DefaultPlatformUtility();
  }
}
