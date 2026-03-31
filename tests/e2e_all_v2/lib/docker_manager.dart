import 'dart:io';
import 'dart:convert';

import 'package:at_utils/at_utils.dart';

AtSignLogger logger = AtSignLogger('docker_manager');

enum DockerImageType {
  release, // "v5.9.4", "v5.11.3", "c0.0.1"
  branch, // "trunk", *commithash*
  current, // represents the current code on the machine (latest)
}

enum Language {
  dart,
  c,
}

class DockerImage {
  final Language language;
  final DockerImageType imageType;
  final String tag; // e.g. "v5.9.4", "trunk", "commit hash", "current"
  late String fullImageName; // e.g. 'atsigncompany/e2e_lal_v2_dart:v5.9.4'

  DockerImage._({
    required this.language,
    required this.imageType,
    required this.tag,
  }) {
    fullImageName = 'atsigncompany/noports_e2e_all_${language.name}:$tag';
  }

  factory DockerImage.release({
    required final Language language,
    required final String version, // e.g. "5.9.4" or "v5.9.4"
  }) {
    return DockerImage._(
      language: language,
      imageType: DockerImageType.release,
      tag: version,
    );
  }

  factory DockerImage.current({
    required final Language language, 
  }) {
    return DockerImage._(
      language: language,
      imageType: DockerImageType.current,
      tag: 'current',
    );
  }

  factory DockerImage.branch({
    required final Language language,
    required final String branch, // branch name like "trunk" or a commit hash
  }) {
    return DockerImage._(
      language: language,
      imageType: DockerImageType.branch,
      tag: branch,
    );
  }

  Future<bool> existsOnMachine() async {
    final String executable = 'docker';
    final List<String> args = [
      'images',
      '-q', fullImageName,
    ];
    final ProcessResult processResult = await Process.run(executable, args);
    bool exists = processResult.stdout.toString().trim().isNotEmpty;
    return exists;
  }

  Future<Process> pull({bool quiet = true}) async {
    // sudo docker pull $imageName --quiet
    final String executable = 'docker';
    final List<String> args = [
      'pull',
      '$fullImageName',
    ];
    if(quiet) {
      args.add('--quiet');
    }
    print('Executing $executable ${args.join(' ')}'); // TODO logger
    return Process.start(executable, args, runInShell: true);
  }

  Future<Process> build({
    final bool forceOverwriteCache = false,
    final bool quiet = false,
  }) async {
    // sudo docker build \
    //  -f $dockerfile \
    //  -t $tag \
    //  --quiet \
    //  ?--no-cache \
    //  ?--build-arg release=v5.9.4 \
    // --target runtime \
    // .
    final String dockerfile = 
      'tests/e2e_all_v2/tools/dockerfiles/'
      'Dockerfile.${language.name}.${imageType.name}';
    final String executable = 'docker';
    List<String> args = [
      'build',
      '-f', dockerfile,
      '-t', fullImageName,
      '--target', 'runtime',
    ];
    if(forceOverwriteCache) {
      args.add('--no-cache');
    }
    if(quiet) {
      args.add('--quiet');
    }
    if(imageType == DockerImageType.release) {
      args.add('--build-arg');
      args.add('release=$tag');
    }
    args.add('.'); // context is this directory
    print('Executing $executable ${args.join(' ')}'); // TODO logger
    final Process process = await Process.start(
      executable,
      args,
      runInShell: true,
      );
    return process;
  }
}

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
  late String containerName; // image tag

  Process? process; // instantiated from run()

  final List<String> _stdoutLines = [];
  final List<String> _stderrLines = [];
  final int maxLogLines = 10000; // prevent unbounded memory growth
  File? _logFile;

  DockerInstance({required this.dockerImage}) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.tag}_$testRunId';
  }

  List<String> get stdoutLogs => List.unmodifiable(_stdoutLines);

  List<String> get stderrLogs => List.unmodifiable(_stderrLines);

  String get allLogs {
    final buffer = StringBuffer();
    for (final line in _stdoutLines) {
      buffer.writeln('[STDOUT] $line');
    }
    for (final line in _stderrLines) {
      buffer.writeln('[STDERR] $line');
    }
    return buffer.toString();
  }

  Future<Process> run({
    final List<String> entrypoint = const <String>[],
    final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    final bool quiet = false,
    final bool removeWhenStopped = true,
    final bool captureLogsToFile = false,
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

    // set up log file if requested
    if (captureLogsToFile) {
      final logDir = logDirectory ?? '.';
      final logPath = '$logDir/$containerName.log';
      _logFile = File(logPath);
      await _logFile!.create(recursive: true);
      logger.info('Logging to file: $logPath');
    }

    _startLogCapture();

    return pr;
  }

  void _startLogCapture() {
    if (process == null) return;

    // stdout
    process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _addStdoutLine(line);
      },
      onError: (error) => logger.severe('Error reading stdout: $error'),
    );

    // stderr
    process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _addStderrLine(line);
      },
      onError: (error) => logger.severe('Error reading stderr: $error'),
    );
  }

  void _addStdoutLine(String line) {
    if (_stdoutLines.length >= maxLogLines) {
      _stdoutLines.removeAt(0);
    }
    _stdoutLines.add(line);
    _logFile?.writeAsStringSync('[STDOUT] $line\n', mode: FileMode.append);
  }

  void _addStderrLine(String line) {
    if (_stderrLines.length >= maxLogLines) {
      _stderrLines.removeAt(0);
    }
    _stderrLines.add(line);
    _logFile?.writeAsStringSync('[STDERR] $line\n', mode: FileMode.append);
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

  Future<int> stop() async {
    const String executable  = 'docker';
    final List<String> args = [
      'container', 'stop',
      containerName,
    ];
    print('Executing \"${executable} ${args.join(' ')}\"');
    final ProcessResult processResult = await Process.run(executable, args);
    return processResult.exitCode;

  }
}

