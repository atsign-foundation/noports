import 'dart:async';
import 'dart:io';

class ProcessOutputCapture {
  final Process process;
  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  final File? stdoutLogFile;
  final File? stderrLogFile;
  IOSink? _stdoutSink;
  IOSink? _stderrSink;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;

  ProcessOutputCapture({
    required this.process,
    this.stdoutLogFile,
    this.stderrLogFile,
  }) {
    final File? stdoutFile = stdoutLogFile;
    final File? stderrFile = stderrLogFile;

    if (stdoutFile != null && !stdoutFile.existsSync()) {
      stdoutFile.createSync(recursive: true);
    }
    if (stderrFile != null && !stderrFile.existsSync()) {
      stderrFile.createSync(recursive: true);
    }

    if (stdoutFile != null) {
      _stdoutSink = stdoutFile.openWrite();
    }
    if (stderrFile != null) {
      _stderrSink = stderrFile.openWrite();
    }

    _stdoutSub = process.stdout.listen((data) {
      final str = String.fromCharCodes(data);
      stdoutBuffer.write(str);
      _stdoutSink?.add(data);
    });

    _stderrSub = process.stderr.listen((data) {
      final str = String.fromCharCodes(data);
      stderrBuffer.write(str);
      _stderrSink?.add(data);
    });
  }

  Future<int> get exitCode async {
    final code = await process.exitCode;
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    await _stdoutSink?.close();
    await _stderrSink?.close();
    return code;
  }

  String get stdout => stdoutBuffer.toString();
  String get stderr => stderrBuffer.toString();
}

/// Interactive process capture that allows stdin interaction and line-by-line stdout monitoring
/// while still capturing to buffers and log files
class InteractiveProcessCapture {
  final Process process;
  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  final File? stdoutLogFile;
  final File? stderrLogFile;
  final StreamController<String> stdoutLineController = StreamController<String>();

  IOSink? _stdoutSink;
  IOSink? _stderrSink;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  String _currentLine = '';

  InteractiveProcessCapture({
    required this.process,
    this.stdoutLogFile,
    this.stderrLogFile,
  }) {
    final File? stdoutFile = stdoutLogFile;
    final File? stderrFile = stderrLogFile;

    // Ensure log files exist before opening
    if (stdoutFile != null && !stdoutFile.existsSync()) {
      stdoutFile.createSync(recursive: true);
    }
    if (stderrFile != null && !stderrFile.existsSync()) {
      stderrFile.createSync(recursive: true);
    }

    // Open sinks for efficient writing
    if (stdoutFile != null) {
      _stdoutSink = stdoutFile.openWrite();
    }
    if (stderrFile != null) {
      _stderrSink = stderrFile.openWrite();
    }

    // Capture stdout with line parsing
    _stdoutSub = process.stdout.listen((data) {
      final str = String.fromCharCodes(data);
      stdoutBuffer.write(str);
      _stdoutSink?.add(data);

      // Parse into lines for line-by-line monitoring
      for (int i = 0; i < str.length; i++) {
        if (str[i] == '\n') {
          stdoutLineController.add(_currentLine);
          _currentLine = '';
        } else {
          _currentLine += str[i];
        }
      }
    });

    // Capture stderr
    _stderrSub = process.stderr.listen((data) {
      final str = String.fromCharCodes(data);
      stderrBuffer.write(str);
      _stderrSink?.add(data);
    });
  }

  Future<int> get exitCode async {
    final code = await process.exitCode;
    // Clean up resources after process completes
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    await stdoutLineController.close();
    await _stdoutSink?.close();
    await _stderrSink?.close();
    return code;
  }

  String get stdout => stdoutBuffer.toString();
  String get stderr => stderrBuffer.toString();

  /// Access to stdin for interactive commands
  IOSink get stdin => process.stdin;

  /// Stream of stdout lines for monitoring (e.g., detecting "Last login:")
  Stream<String> get stdoutLines => stdoutLineController.stream;

  /// Kill the process
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => process.kill(signal);
}

Future<InteractiveProcessCapture> startInteractiveCommand(
  final String executable,
  final List<String> arguments, {
  required final File stdoutLogFile,
  required final File stderrLogFile,
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
}) async {
  final Process process = await startCommand(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    printCommand: printCommand,
  );
  return InteractiveProcessCapture(
    process: process,
    stdoutLogFile: stdoutLogFile,
    stderrLogFile: stderrLogFile,
  );
}

Future<ProcessOutputCapture> startCommandWithCapture(
  final String executable,
  final List<String> arguments, {
  required final File stdoutLogFile,
  required final File stderrLogFile,
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
}) async {
  final Process process = await startCommand(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    printCommand: printCommand
  );
  return ProcessOutputCapture(
    process: process,
    stdoutLogFile: stdoutLogFile,
    stderrLogFile: stderrLogFile,
  );
}

Future<ProcessResult> runCommand(
  final String executable,
  final List<String> arguments, {
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
  final bool printOutput = false,
  final File? stdoutLogFile,
  final File? stderrLogFile,
}) async {
  if(printCommand) {
    print('> $executable ${arguments.join(' ')}');
  }
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printOutput) {
    print('stdout:\n\t${result.stdout}');
    print('stderr:\n\t${result.stderr}');
  }
  if(stdoutLogFile != null) {
    if (!stdoutLogFile.existsSync()) {
      stdoutLogFile.createSync(recursive: true);
    }
    await stdoutLogFile.writeAsString(result.stdout.toString());
  }
  if(stderrLogFile != null) {
    if (!stderrLogFile.existsSync()) {
      stderrLogFile.createSync(recursive: true);
    }
    await stderrLogFile.writeAsString(result.stderr.toString());
  }
  return result;
}

Future<Process> startCommand(
  final String executable,
  final List<String> arguments, {
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
  final bool printOutput = false,
  final File? stdoutLogFile,
  final File? stderrLogFile,
}) async {
  if(printCommand) {
    print('> $executable ${arguments.join(' ')}');
  }
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printOutput) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stdout: $data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stderr: $data');
    });
  }
  if(stdoutLogFile != null) {
    if (!stdoutLogFile.existsSync()) {
      stdoutLogFile.createSync(recursive: true);
    }
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      stdoutLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  if(stderrLogFile != null) {
    if (!stderrLogFile.existsSync()) {
      stderrLogFile.createSync(recursive: true);
    }
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      stderrLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  return process;
}
