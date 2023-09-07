import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/repository/navigation_service.dart';

class CustomSnackBar {
  static void error({
    required String content,
  }) {
    final context = NavigationService.navKey.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  static void success({
    required String content,
  }) {
    final context = NavigationService.navKey.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: const Color(0xffC4FF79),
    ));
  }

  static void notification({
    required String content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    final context = NavigationService.navKey.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      action: action,
      duration: duration,
      // backgroundColor: kDataStorageColor,
    ));
  }
}
