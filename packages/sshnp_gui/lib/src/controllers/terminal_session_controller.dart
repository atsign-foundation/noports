import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

/// A provider that exposes the [TerminalSessionController] to the app.
final terminalSessionController = NotifierProvider<TerminalSessionController, String>(
  TerminalSessionController.new,
);

/// A provider that exposes the [TerminalSessionListController] to the app.
final terminalSessionListController = NotifierProvider<TerminalSessionListController, List<String>>(
  TerminalSessionListController.new,
);

/// A provider that exposes the [TerminalSessionFamilyController] to the app.
final terminalSessionFamilyController =
    NotifierProviderFamily<TerminalSessionFamilyController, TerminalSession, String>(
  TerminalSessionFamilyController.new,
);

final terminalSessionProfileNameFamilyCounter =
    NotifierProviderFamily<TerminalSessionProfileNameFamilyCounter, int, String>(
  TerminalSessionProfileNameFamilyCounter.new,
);

/// Controller for the id of the currently active terminal session
class TerminalSessionController extends Notifier<String> {
  @override
  String build() => '';

  String createSession() {
    state = const Uuid().v4();
    ref.read(terminalSessionListController.notifier)._add(state);
    return state;
  }

  void setSession(String sessionId) {
    state = sessionId;
  }
}

/// Controller for the list of all terminal session ids
class TerminalSessionListController extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void _add(String sessionId) {
    state = state + [sessionId];
  }

  void _remove(String sessionId) {
    state.remove(sessionId);
  }
}

class TerminalSession {
  final String sessionId;
  final Terminal terminal;

  String? _profileName;
  String displayName;

  late Pty pty;
  bool isRunning = false;
  bool isDisposed = true;
  String? command;
  List<String> args = const [];

  TerminalSession(this.sessionId)
      : terminal = Terminal(maxLines: 10000),
        displayName = sessionId;
}

/// Controller for the family of terminal session [TerminalController]s
class TerminalSessionFamilyController extends FamilyNotifier<TerminalSession, String> {
  @override
  TerminalSession build(String arg) {
    return TerminalSession(arg);
  }

  String get displayName => state.displayName;

  void issueDisplayName(String profileName) {
    state._profileName = profileName;
    state.displayName =
        ref.read(terminalSessionProfileNameFamilyCounter(profileName).notifier)._addSession(state.sessionId);
  }

  void setProcess({String? command, List<String> args = const []}) {
    state.command = command;
    state.args = args;
  }

  void startProcess() {
    if (state.isRunning) return;
    state.isRunning = true;
    state.isDisposed = false;
    state.pty = Pty.start(
      state.command ?? Platform.environment['SHELL'] ?? 'bash',
      arguments: state.args,
      columns: state.terminal.viewWidth,
      rows: state.terminal.viewHeight,
      environment: Platform.environment,
      workingDirectory: Platform.environment['HOME'],
    );

    final command = '${state.pty.executable} ${state.pty.arguments.join(' ')}';
    state.terminal.setTitle(command);

    // Write the command to the terminal
    state.terminal.write('[Process: $command]\r\n\n');

    // Write stdout of the process to the terminal
    state.pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(state.terminal.write);

    // Write exit code of the process to the terminal
    state.pty.exitCode.then((code) async {
      state.terminal.write('\n[The process exited with code: $code]\r\n\n');
      state.terminal.setCursorVisibleMode(false);

      int delay = 5;

      /// Count down to closing the terminal
      for (int i = 0; i < delay; i++) {
        String message = 'Closing terminal session in ${delay - i} seconds...\r';
        state.terminal.write(message);
        await Future.delayed(const Duration(seconds: 1));
      }

      /// Close the terminal after [delay] seconds
      state.isRunning = false;
      dispose();
    });

    // Write the terminal output to the process
    state.terminal.onOutput = (data) {
      state.pty.write(const Utf8Encoder().convert(data));
    };

    // Resize the terminal when the window is resized
    state.terminal.onResize = (w, h, pw, ph) {
      state.pty.resize(h, w);
    };
  }

  void _killProcess() {
    state.pty.kill();
    state.isRunning = false;
  }

  void dispose() {
    /// If the session is already disposed, return null
    if (state.isDisposed) return;

    /// 1. Set the session to disposed
    if (state.isRunning) _killProcess();

    // 2. Find a new session to set as the active one
    final terminalList = ref.read(terminalSessionListController);
    final currentSessionId = ref.read(terminalSessionController);
    final currentIndex = terminalList.indexOf(currentSessionId);
    if (currentSessionId == state.sessionId) {
      // Find a new terminal tab to set as the active one
      if (currentIndex > 0) {
        // set active terminal to the one immediately to the left
        ref.read(terminalSessionController.notifier).setSession(terminalList[currentIndex - 1]);
      } else if (terminalList.length > 1) {
        // set active terminal to the one immediately to the right
        ref.read(terminalSessionController.notifier).setSession(terminalList[currentIndex + 1]);
      } else {
        // no other sessions available, set active terminal to empty string
        ref.read(terminalSessionController.notifier).setSession('');
      }
    }

    /// 3. Remove the session from the list of sessions
    ref.read(terminalSessionListController.notifier)._remove(state.sessionId);

    /// 4. Remove the session from the profile name counter
    if (state._profileName != null) {
      ref.read(terminalSessionProfileNameFamilyCounter(state._profileName!).notifier)._removeSession(state.sessionId);
    }
  }
}

/// Counter for the number of terminal sessions by profileName - issues and tracks the display name for each session
class TerminalSessionProfileNameFamilyCounter extends FamilyNotifier<int, String> {
  @override
  int build(String arg) => 0;

  final List<String?> _sessionQueue = [];

  String _addSession(String sessionId) {
    state++;
    for (int i = 0; i < _sessionQueue.length; i++) {
      if (_sessionQueue[i] == null) {
        _sessionQueue[i] = sessionId;
        return '$arg-${i + 1}';
      }
    }
    _sessionQueue.add(sessionId);
    return '$arg-${_sessionQueue.length}';
  }

  bool _removeSession(String sessionId) {
    for (int i = 0; i < _sessionQueue.length; i++) {
      if (_sessionQueue[i] == sessionId) {
        _sessionQueue[i] = null;
        state--;
        return true;
      }
    }
    return false;
  }
}
