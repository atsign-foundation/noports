import 'package:flutter/material.dart';

import '../../repository/navigation_service.dart';

final _context = NavigationService.navKey.currentContext!;

class SnackBars extends StatelessWidget {
  const SnackBars({Key? key}) : super(key: key);
  static void errorSnackBar({
    required String content,
  }) {
    ScaffoldMessenger.of(_context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: Theme.of(_context).colorScheme.error,
    ));
  }

  static void successSnackBar({
    required String content,
  }) {
    ScaffoldMessenger.of(_context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      backgroundColor: const Color(0xffC4FF79),
    ));
  }

  static void notificationSnackBar({
    required String content,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(_context).showSnackBar(SnackBar(
      content: Text(
        content,
        textAlign: TextAlign.center,
      ),
      action: action,
      duration: duration,
      // backgroundColor: kDataStorageColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
