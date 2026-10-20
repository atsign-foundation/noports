import 'dart:async';

import 'package:flutter/material.dart';

/// Runs [task] behind a modal progress indicator on the root navigator, and
/// removes that indicator however [task] ends.
///
/// Only the indicator's own route is removed, so a route pushed above it while
/// [task] runs stays where it is.
Future<T> runWithProgressIndicator<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  unawaited(navigator.push(route));
  try {
    return await task();
  } finally {
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }
}
