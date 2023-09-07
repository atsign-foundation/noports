import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
    AutoDisposeNotifierProviderFamily<TerminalSessionFamilyController, TerminalSession, String>(
  TerminalSessionFamilyController.new,
);

/// Controller for the id of the currently active terminal session
class TerminalSessionController extends AutoDisposeNotifier<String> {
  @override
  String build() => '';

  String createSession() {
    state = const Uuid().v4();
    ref.read(terminalSessionListController.notifier).add(state);
    return state;
  }
}

/// Controller for the list of all terminal session ids
class TerminalSessionListController extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String sessionId) {
    state.add(sessionId);
  }

  void remove(String sessionId) {
    state.remove(sessionId);
  }
}

class TerminalSession {
  final String sessionId;
  final Terminal terminal;

  late Pty pty;
  bool isRunning = false;
  String? command;
  List<String> args = const [];

  TerminalSession(this.sessionId) : terminal = Terminal();
}

/// Controller for the family of terminal session [TerminalController]s
class TerminalSessionFamilyController extends AutoDisposeFamilyNotifier<TerminalSession, String> {
  @override
  TerminalSession build(String arg) {
    return TerminalSession(arg);
  }

  void setProcess({String? command, List<String> args = const []}) {
    state.command = command;
    state.args = args;
  }

  void startProcess() {
    state.isRunning = true;
    state.pty = Pty.start(
      state.command ?? Platform.environment['SHELL'] ?? 'bash',
      arguments: state.args,
      columns: state.terminal.viewWidth,
      rows: state.terminal.viewHeight,
    );

    // Write stdout of the process to the terminal
    state.pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(state.terminal.write);

    // Write exit code of the process to the terminal
    state.pty.exitCode.then((code) => state.terminal.write('The process exited with code: $code'));

    // Write the terminal output to the process
    state.terminal.onOutput = (data) {
      state.pty.write(const Utf8Encoder().convert(data));
    };

    // Resize the terminal when the window is resized
    state.terminal.onResize = (w, h, pw, ph) {
      state.pty.resize(h, w);
    };
  }

  void killProcess() {
    state.pty.kill();
    state.isRunning = false;
  }
}
