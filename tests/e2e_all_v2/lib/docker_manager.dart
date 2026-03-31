import 'dart:io';

import 'package:at_utils/at_utils.dart';

AtSignLogger logger = AtSignLogger('docker_manager');

enum DockerImageType {
  release, // "v5.9.4", "v5.11.3", "c0.0.1"
  branch, // "trunk", *commithash*
  current, // represents the current code on the machine (latest)
}

enum E2EAllV2Language {
  dart,
  c,
}

enum DockerInstanceState {
  stopped,
  starting,
  started,
}

class DockerImage {
  final E2EAllV2Language language;
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
    required final E2EAllV2Language language,
    required final String version, // e.g. "5.9.4" or "v5.9.4"
  }) {
    return DockerImage._(
      language: language,
      imageType: DockerImageType.release,
      tag: version,
    );
  }

  factory DockerImage.current({
    required final E2EAllV2Language language, 
  }) {
    return DockerImage._(
      language: language,
      imageType: DockerImageType.current,
      tag: 'current',
    );
  }

  factory DockerImage.branch({
    required final E2EAllV2Language language,
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
      // '--quiet',
      '--target', 'runtime',
    ];
    if(forceOverwriteCache) {
      args.add('--no-cache');
    }
    if(imageType == DockerImageType.release) {
      args.add('--build-arg');
      args.add('release=$tag');
    }
    args.add('.');
    print('Executing $executable ${args.toString()}'); // TODO logger
    final Process process = await Process.start(
      executable,
      args,
      runInShell: true,
      );
    return process;
  }

  static String _getDockerImageName({
    required final E2EAllV2Language language, // e.g. "c", "dart"
    required final String tag, // e.g. "v5.9.4" "c0.0.1" or "current" "trunk"
  }) {
    return 'atsigncompany/noports_e2e_all_${language.name}:$tag';
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

class DockerRunFlags {
  bool quiet = false; // --quiet
  bool removeWhenStopped = false; // --rm
}

class DockerInstance {
  final DockerImage dockerImage;
  late String containerName; // image tag
  DockerInstanceState _state = DockerInstanceState.stopped;

  DockerInstance({
    required this.dockerImage,
  }) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.imageType.name}_${dockerImage.tag}';
  }

  Future<Process> run({
    required final String executable,
    List<String> entrypoint = const <String>[],
    List<VolumeMapping> volumeMappings = const <VolumeMapping>[],
    DockerRunFlags? dockerRunFlags,
  }) async {
    _state = DockerInstanceState.starting;
    List<String> args = [
      'run',
      '--name', containerName,
    ];
    if(dockerRunFlags != null) {
      if(dockerRunFlags.quiet) {
        args.add('--quiet');
      }

      if(dockerRunFlags.removeWhenStopped) {
        args.add('--rm');
      }
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
    if((await process.exitCode) == 0) {
      _state = DockerInstanceState.started;
    } else {
      final bool success = process.kill(ProcessSignal.sigterm);
      if(success) {

        _state = DockerInstanceState.stopped;
      }
    }
    return process;
  }

  Future<DockerInstanceState> getState() async {
    final String executable = 'docker';
    List<String> args = [
      // docker ps --filter "name=e2e_all_v2_dart_DockerImageType.release_v5.9.4"
      'ps',
      '-q' // quiet , if container is found, it will print something out in stdout
      '--filter', containerName
    ];

    final ProcessResult processResult = await Process.run(executable, args);
    if(processResult.stdout.length > 0) {
      _state = DockerInstanceState.started;
    } else {
      _state = DockerInstanceState.stopped;
    }
    return _state;
  }
}

class DockerManager {
  final List<DockerInstance> dockerInstances = [];

  DockerManager() {
  }
}
