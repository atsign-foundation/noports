import 'dart:io';
import 'dart:convert';
import 'package:e2e_all_v2/docker_image.dart';

class VolumeMapping {
  final Directory localDirectory;
  final Directory containerDirectory;

  VolumeMapping({
    required this.localDirectory,
    required this.containerDirectory,
  });
}

class DockerInstance {
  final DockerImage dockerImage;
  final String testRunId;
  late String containerName; // image tag

  Process? process; // instantiated from run()
  Process? _dockerLogsProcess; // process for docker logs -f

  File? _stdoutFile;
  File? _stderrFile;
  File? _daemonStdoutFile;
  File? _daemonStderrFile;

  DockerInstance({
    required this.dockerImage,
    required this.testRunId,
    String uniqueIdentifier = '',
  }) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.tag}_$testRunId';
    if(uniqueIdentifier.isNotEmpty) {
      containerName += '_$uniqueIdentifier';  
    }
  }

  // Read stdout logs from file
  List<String> get stdoutLogs {
    if (_stdoutFile == null || !_stdoutFile!.existsSync()) return [];
    return _stdoutFile!.readAsLinesSync();
  }

  // Read stderr logs from file
  List<String> get stderrLogs {
    if (_stderrFile == null || !_stderrFile!.existsSync()) return [];
    return _stderrFile!.readAsLinesSync();
  }

  // Read all logs combined from files
  String get allLogs {
    final buffer = StringBuffer();
    for (final line in stdoutLogs) {
      buffer.writeln('[STDOUT] $line');
    }
    for (final line in stderrLogs) {
      buffer.writeln('[STDERR] $line');
    }
    return buffer.toString();
  }

  // Get the stdout log file path
  String? get stdoutLogPath => _stdoutFile?.path;

  // Get the stderr log file path
  String? get stderrLogPath => _stderrFile?.path;

  Future<Process> run({
    final List<String> entrypoint = const <String>[],
    final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    final bool quiet = false,
    final bool removeWhenStopped = true,
    final String? logDirectory,
  }) async {
    const String executable = 'docker';

    // construct args
    final List<String> args = [
      'run',
      '--name', containerName,
    ];

    if(quiet) {
      args.add('--quiet');
    }
    if(removeWhenStopped) {
      args.add('--rm');
    }
    for(final VolumeMapping volumeMapping in volumeMappings) {
      args.add('--volume');
      args.add('${volumeMapping.localDirectory.path}:${volumeMapping.containerDirectory.path}');
    }
    args.add(dockerImage.fullImageName);
    args.addAll(entrypoint);

    // use start, spawns a process
    print('Executing ${executable} ${args.join(' ')}');
    final Process pr = await Process.start(executable, args);
    process = pr;

    // Set up log files for container entrypoint stdout/stderr
    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _stdoutFile = File('$logDirectory/entrypoint_${containerName}_${timestamp}_stdout.log');
      _stderrFile = File('$logDirectory/entrypoint_${containerName}_${timestamp}_stderr.log');
      print('Container entrypoint logs: ${_stdoutFile!.path} / ${_stderrFile!.path}');

      _startLogCapture();

      // Also capture daemon logs using docker logs -f
      _daemonStdoutFile = File('$logDirectory/daemon_${containerName}_${timestamp}_stdout.log');
      _daemonStderrFile = File('$logDirectory/daemon_${containerName}_${timestamp}_stderr.log');
      print('Container daemon logs: ${_daemonStdoutFile!.path} / ${_daemonStderrFile!.path}');

      await _startDaemonLogCapture();
    }

    return pr;
  }

  void _startLogCapture() {
    if (process == null) return;

    // stdout - write directly to file only
    process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _stdoutFile?.writeAsStringSync('$line\n', mode: FileMode.append);
      },
      onError: (error) => print('Error reading stdout: $error'),
    );

    // stderr - write directly to file only
    process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _stderrFile?.writeAsStringSync('$line\n', mode: FileMode.append);
      },
      onError: (error) => print('Error reading stderr: $error'),
    );
  }

  Future<void> _startDaemonLogCapture() async {
    // Wait a moment for container to start
    await Future.delayed(const Duration(milliseconds: 500));

    // Start docker logs -f to capture daemon output
    try {
      _dockerLogsProcess = await Process.start(
        'docker',
        ['logs', '-f', containerName],
      );

      // Capture stdout from daemon
      _dockerLogsProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          _daemonStdoutFile?.writeAsStringSync('$line\n', mode: FileMode.append);
        },
        onError: (error) => print('Error reading daemon stdout: $error'),
      );

      // Capture stderr from daemon
      _dockerLogsProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          _daemonStderrFile?.writeAsStringSync('$line\n', mode: FileMode.append);
        },
        onError: (error) => print('Error reading daemon stderr: $error'),
      );
    } catch (e) {
      print('Error starting daemon log capture for $containerName: $e');
    }
  }

  Future<bool> isActive() async {
    // docker ps --filter "name=e2e_all_v2_dart_DockerImageType.release_v5.9.4"
    const String executable = 'docker';
    final List<String> args = [
      'ps',
      '-q' // quiet , if container is found, it will print something out in stdout
      '--filter', containerName
    ];

    final ProcessResult processResult = await Process.run(executable, args);
    if(processResult.stdout.length > 0) { // since we're using `-q`, the length will be > 0 if the container is active
      return true;
    } else {
      return false;
    }
  }

  Future<int> stop({String? logDirectory}) async {
    // Kill docker logs process if running
    if (_dockerLogsProcess != null) {
      _dockerLogsProcess!.kill();
      await _dockerLogsProcess!.exitCode;
      _dockerLogsProcess = null;
    }

    const String executable  = 'docker';
    final List<String> args = [
      'container', 'stop',
      containerName,
    ];
    print('Executing \"${executable} ${args.join(' ')}\"');
    final ProcessResult processResult = await Process.run(executable, args);

    // Log stop command output if logDirectory specified
    if (logDirectory != null) {
      await Directory(logDirectory).create(recursive: true);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/stop_${containerName}_$timestamp';

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      await stdoutFile.writeAsString(processResult.stdout.toString());
      await stderrFile.writeAsString(processResult.stderr.toString());

      print('Docker stop logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    return processResult.exitCode;
  }
}
