import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/repository/navigation_repository.dart';

class CustomSnackBar {
  static void error({
    required String content,
    Duration duration = const Duration(seconds: 2),
  }) {
    final context = NavigationRepository.navKey.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: duration,
    ));
  }

  static void success({
    required String content,
    Duration duration = const Duration(seconds: 2),
  }) {
    final context = NavigationRepository.navKey.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: const Color(0xffC4FF79),
      duration: duration,
    ));
  }

  static void notification({
    required String content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    final context = NavigationRepository.navKey.currentContext!;
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
