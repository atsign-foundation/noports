import 'dart:io';

enum DockerImageType {
  release, // "v5.9.4", "v5.11.3", "c0.0.1"
  branch, // "trunk", *commithash*
  current, // represents the current code on the machine (latest)
}

enum Language {
  dart,
  c,
}

enum DockerInstanceState {
  stopped,
  starting,
  started,
}

class DockerImage {
  final Language language;
  final DockerImageType imageType;
  final String imageName;
  final String tag; // e.g. "v5.9.4", "trunk", "commit hash", "current"

  DockerImage._({
    required this.language,
    required this.imageType,
    required this.imageName,
    required this.tag,
  });

  factory DockerImage.release({
    required final Language language,
    required final String version, // e.g. "5.9.4" or "v5.9.4"
  }) {
    final String dockerImageName = _getDockerImageName(
      language: language,
      tag: version); // e.g. "atsigncompany/noports_e2e_all_dart:v5.9.4
    // final String dockerfile = 'Dockerfile.$language.release';
    return DockerImage._(
      language: language,
      imageType: DockerImageType.release,
      imageName: dockerImageName,
      tag: version,
    );
  }

  factory DockerImage.current({
    required final Language language, 
  }) {
    final String dockerImageName = _getDockerImageName(
      language: language,
      tag: 'current');
    // final String dockerfile = 'Dockerfile.$language.current';
    return DockerImage._(
      language: language,
      imageType: DockerImageType.current,
      imageName: dockerImageName,
      tag: 'current',
    );
  }

  factory DockerImage.branch({
    required final Language language,
    required final String branch, // branch name like "trunk" or a commit hash
  }) {
    final String dockerImageName = _getDockerImageName(
      language: language,
      tag: branch);
    // final String dockerfile = 'Dockerfile.$language.branch';
    return DockerImage._(
      language: language,
      imageType: DockerImageType.branch,
      imageName: dockerImageName,
      tag: branch,
    );
  }

  Future<Process> tryPull() async {
    // sudo docker pull $imageName --quiet
    final String executable = 'docker';
    final List<String> args = [
      'pull',
      '$imageName:$tag',
      '--quiet',
    ];
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
      '-t', imageName,
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
    final Process process = await Process.start(
      executable,
      args,
      runInShell: true,
      );
    return process;
  }

  static String _getDockerImageName({
    required final Language language, // e.g. "c", "dart"
    required final String tag, // e.g. "v5.9.4" or "current"
  }) {
    return 'atsigncompany/noports_e2e_all_${language.name}:$tag';
  }

}

class DockerInstance {
  final DockerImage dockerImage;
  late String containerName; // image tag
  DockerInstanceState _state = DockerInstanceState.stopped;

  DockerInstance({
    required this.dockerImage,
  }) {
    containerName = 'e2e_all_v2_${dockerImage.language.name}_${dockerImage.imageType}_${dockerImage.tag}';
  }

  Future<Process> run({required final String command}) async {
    _state = DockerInstanceState.starting;
    final String dockerImageName = dockerImage.imageName;
    final String executable = 'docker';
    // temp --- start
    final String daemonAt = '@device_jttest';
    final String clientAt = '@client_jttest';
    final String daemonFlags = '-s -u';
    final String atDirectoryHost = 'root.atsign.org';
    final String deviceName = 'default';
    // temp --- end
    List<String> args = [
      'run',
      '--rm', // remove when stopped
      '--name', containerName,
      '-v', '/Users/jeremytubongbanua/.atsign/keys/:/atsign/.atsign/keys/',
      dockerImageName,
      '/bin/bash',
      '-c',
      'sudo service ssh start && /usr/local/bin/sshnpd'
        ' -a $daemonAt'
        ' -m $clientAt'
        ' -d $deviceName'
        ' --root-domain $atDirectoryHost'
        ' -v'
        ' $daemonFlags',
    ];
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
