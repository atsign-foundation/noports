import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

/// A provider that exposes the [TerminalSessionController] to the app.
final terminalSessionController = AutoDisposeNotifierProvider<TerminalSessionController, String>(
  TerminalSessionController.new,
);

/// A provider that exposes the [TerminalSessionListController] to the app.
final terminalSessionListController = AutoDisposeNotifierProvider<TerminalSessionListController, Set<String>>(
  TerminalSessionListController.new,
);

/// A provider that exposes the [TerminalSessionFamilyController] to the app.
final terminalSessionFamilyController =
    AutoDisposeNotifierProviderFamily<TerminalSessionFamilyController, TerminalController, String>(
  TerminalSessionFamilyController.new,
);

/// Controller for the id of the currently active terminal session
class TerminalSessionController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  void setState(String sessionId) {
    state = sessionId;
  }
}

/// Controller for the list of all terminal session ids
class TerminalSessionListController extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => {};
}

/// Controller for the family of terminal session [TerminalController]s
class TerminalSessionFamilyController extends AutoDisposeFamilyNotifier<TerminalController, String> {
  @override
  TerminalController build(String arg) {
    return TerminalController();
  }
}
