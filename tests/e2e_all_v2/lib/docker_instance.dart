import 'dart:convert';
import 'dart:io';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/log_fragment.dart';
import 'package:e2e_all_v2/process_utils.dart';
import 'package:e2e_all_v2/utils.dart';

class VolumeMapping {
  final Directory localDirectory;
  final String containerDirectory;

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
  Process? logProcess; // instantiated from run() // sudo docker logs -f <containerName> 1>> <stdoutLogFile> 2>> <stderrLogFile>
  File? stdoutLogFile; // instantiated from run()
  File? stderrLogFile; // instantiated from run()

  final List<LogFragment> _activeFragments = [];

  DockerInstance({
    required this.dockerImage,
    required this.testRunId,
    String uniqueIdentifier = '',
    String? containerName,
  }) {
    if(containerName != null) {
      this.containerName = containerName;
    } else {
      this.containerName = _getDockerContainerName(language: dockerImage.language.name, tag: dockerImage.tag, testRunId: testRunId);
      if(uniqueIdentifier.isNotEmpty) {
        this.containerName += '$uniqueIdentifier';  
      }
    }
  }

  Future<Process> run({
    final List<String> entrypoint = const <String>[],
    final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    final bool quiet = false,
    final bool removeWhenStopped = true,
    File? stdoutLogFile, // holds logs for full container life-time
    File? stderrLogFile, // holds logs for full container life-time
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
      args.add('${volumeMapping.localDirectory.absolute.path}/:${volumeMapping.containerDirectory}/');
    }
    args.add(dockerImage.fullImageName);
    args.addAll(entrypoint);

    // use start, spawns a process
    final Process process = await startCommand(executable, args);
    this.process = process;
    if(stdoutLogFile != null && stderrLogFile != null) {
      this.stdoutLogFile = stdoutLogFile;
      this.stderrLogFile = stderrLogFile;
      // Wait a moment for the container to be created before starting log capture
      await Future.delayed(Duration(milliseconds: 500));
      await _startDockerLogProcess(stdoutLogFile: stdoutLogFile, stderrLogFile: stderrLogFile);
    } else if(stdoutLogFile == null && stderrLogFile != null || stdoutLogFile != null && stderrLogFile == null) {
      throw Exception('Both stdoutLogFile and stderrLogFile must be provided to capture logs.');
    }
    return process;
  }

  Future<bool> isActive() async {
    // docker ps --filter "name=e2e_all_v2_dart_DockerImageType.release_v5.9.4"
    const String executable = 'docker';
    final List<String> args = [
      'ps',
      '-q' // quiet , if container is found, it will print something out in stdout
      '--filter', containerName
    ];

    final ProcessResult processResult = await runCommand(executable, args);
    if(processResult.stdout.length > 0) { // since we're using `-q`, the length will be > 0 if the container is active
      return true;
    } else {
      return false;
    }
  }

  Future<ProcessResult> stop({String? logDirectory}) async {
    const String executable  = 'docker';
    final List<String> args = [
      'container', 'stop',
      containerName,
    ];
    final ProcessResult processResult = await runCommand(executable, args);
    _stopDockerLogProcess();
    return processResult;
  }

  LogFragment createLogFragment({
    required File stdoutFile,
    required File stderrFile,
  }) {
    final fragment = LogFragment(
      stdoutFile: stdoutFile,
      stderrFile: stderrFile,
      processStarter: () => startCommand(
        'docker',
        [
          'logs',
          '-f',
          containerName,
          '1>>', stdoutFile.absolute.path,
          '2>>', stderrFile.absolute.path,
        ],
      ),
    );

    _activeFragments.add(fragment);
    return fragment;
  }

  void removeLogFragment(LogFragment fragment) {
    _activeFragments.remove(fragment);
  }

  Future<void> stopAllLogFragments() async {
    for (final fragment in List.from(_activeFragments)) {
      await fragment.stop();
      removeLogFragment(fragment);
    }
  }

  Future<void> _startDockerLogProcess({required final File stdoutLogFile, required final File stderrLogFile}) async {
    // Use shell redirection to write stdout and stderr to files
    final Process logProcess = await startCommand(
      'docker',
      [
        'logs',
        '-f',
        containerName
      ],
    );
    logProcess.stdout.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
      stdoutLogFile.writeAsStringSync('$line\n', mode: FileMode.append);
    });
    logProcess.stderr.transform(SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
      stderrLogFile.writeAsStringSync('$line\n', mode: FileMode.append);
    });
    this.logProcess = logProcess;
  }

  bool _stopDockerLogProcess() {
    if(logProcess != null) {
      return logProcess!.kill();
    }
    return true;
  }
}

String _getDockerContainerName({
  required final String language,
  required final String tag,
  required final String testRunId,
}) {
  final String containerName = 'e2e_all_v2_${language}_${tag}_$testRunId';
  return containerName;
}
