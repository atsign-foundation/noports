import 'dart:io';

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
    print('Executing $executable ${args.toString()}'); // TODO logger
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
    print('Executing $executable ${args.toString()}'); // TODO logger
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
  }) {
    if(localDirectory.existsSync()) {
      logger.severe('${localDirectory.path} does not exist!');
    }
    if(containerDirectory.existsSync()) {
      logger.severe('${containerDirectory.path} does not exist!');
    }
  }
}

class DockerInstance {
  final DockerImage dockerImage;
  late String containerName; // image tag

  DockerInstance({required this.dockerImage}) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.imageType.name}_${dockerImage.tag}';
  }

  Future<Process> run({
    required final String executable,
    final List<String> entrypoint = const <String>[],
    final List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    final bool quiet = false,
    final bool removeWhenStopped = false,
  }) async {
    List<String> args = [
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
      args.add('${volumeMapping.localDirectory.path}/:${volumeMapping.containerDirectory.path}/');
    }
    args.add(dockerImage.fullImageName);
    args.addAll(entrypoint);
    // use start, spawns a process
    final Process process = await Process.start(
      executable,
      args,
      runInShell: false);
    return process;
  }

  Future<bool> isActive() async {
    // docker ps --filter "name=e2e_all_v2_dart_DockerImageType.release_v5.9.4"
    final String executable = 'docker';
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
}

class DockerManager {
  final List<DockerInstance> dockerInstances = [];

  DockerManager() {
  }
}
