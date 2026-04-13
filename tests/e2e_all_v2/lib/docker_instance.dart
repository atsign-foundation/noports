import 'dart:io';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/process_utils.dart';

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

  DockerInstance({
    required this.dockerImage,
    required this.testRunId,
    String uniqueIdentifier = '',
  }) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.tag}_$testRunId';
    if(uniqueIdentifier.isNotEmpty) {
      containerName += '$uniqueIdentifier';  
    }
  }

  Future<Process> run({
    final List<String> entrypoint = const <String>[],
    final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    final bool quiet = false,
    final bool removeWhenStopped = true,
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
    final Process pr = await startCommand(executable, args);
    process = pr;
    return pr;
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
    return processResult;
  }
}
