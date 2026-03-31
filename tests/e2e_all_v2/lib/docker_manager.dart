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

  Future<Process> pull({
    bool quiet = true,
    String? logDirectory,
  }) async {
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
    final Process process = await Process.start(executable, args, runInShell: true);

    // Log to files if logDirectory specified
    if (logDirectory != null) {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/pull_${fullImageName.replaceAll(':', '_').replaceAll('/', '_')}_$timestamp';
      await Directory(logDirectory).create(recursive: true);

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });
    }

    return process;
  }

  Future<Process> build({
    final bool forceOverwriteCache = false,
    final bool quiet = false,
    String? logDirectory,
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

    // Log to files if logDirectory specified
    if (logDirectory != null) {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String logPrefix = '$logDirectory/build_${fullImageName.replaceAll(':', '_').replaceAll('/', '_')}_$timestamp';
      await Directory(logDirectory).create(recursive: true);

      final File stdoutFile = File('${logPrefix}_stdout.log');
      final File stderrFile = File('${logPrefix}_stderr.log');

      process.stdout.listen((data) {
        stdoutFile.writeAsBytesSync(data, mode: FileMode.append);
      });

      process.stderr.listen((data) {
        stderrFile.writeAsBytesSync(data, mode: FileMode.append);
      });
    }

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
  final String testRunId;
  late String containerName; // image tag

  Process? process; // instantiated from run()

  File? _stdoutFile;
  File? _stderrFile;

  DockerInstance({
    required this.dockerImage,
    required this.testRunId,
  }) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.tag}_$testRunId';
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
      logger.info('Container entrypoint logs: ${_stdoutFile!.path} / ${_stderrFile!.path}');

      _startLogCapture();
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
      onError: (error) => logger.severe('Error reading stdout: $error'),
    );

    // stderr - write directly to file only
    process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _stderrFile?.writeAsStringSync('$line\n', mode: FileMode.append);
      },
      onError: (error) => logger.severe('Error reading stderr: $error'),
    );
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

      logger.info('Docker stop logs: ${stdoutFile.path} / ${stderrFile.path}');
    }

    return processResult.exitCode;
  }
}
