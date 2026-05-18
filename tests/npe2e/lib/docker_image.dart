import 'dart:io';
import 'package:npe2e/process_utils.dart';
import 'package:path/path.dart' as path;
import 'package:npe2e/language.dart';

enum DockerImageType {
  release, // "v5.9.4", "v5.11.3", "c0.0.1"
  branch, // "trunk", *commithash*
  current, // represents the current code on the machine (latest)
}

class DockerImage {
  final Language language;
  final DockerImageType
  imageType; // imageType = release means tag is a release version like "v5.9.4". imageType = branch means tag is a branch name like "trunk" or a commit hash. imageType = current means tag is "current" and represents the current code on the machine (latest)
  final String tag; // e.g. "v5.9.4", "trunk", "commit hash", "current"
  late String fullImageName; // e.g. 'atsigncompany/e2e_lal_v2_dart:v5.9.4'

  DockerImage._({
    required this.language,
    required this.imageType,
    required this.tag,
  }) {
    fullImageName = _getFullImageName(
      language: language,
      imageType: imageType,
      tag: tag,
    );
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

  factory DockerImage.current({required final Language language}) {
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
    const String executable = 'docker';
    final List<String> args = ['images', '-q', fullImageName];
    final ProcessResult processResult = await Process.run(executable, args);
    bool exists = processResult.stdout.toString().trim().isNotEmpty;
    return exists;
  }

  Future<Process> pull({bool quiet = false}) async {
    // sudo docker pull $imageName --quiet
    const String executable = 'docker';
    final List<String> args = ['pull', '$fullImageName'];
    if (quiet) {
      args.add('--quiet');
    }
    final Process dockerProcess = await startCommand(
      executable,
      args,
    ); // for logging the command being run
    return dockerProcess;
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
    final String dockerfile = path.join(
      _getDockerfilesPath(),
      'Dockerfile.${language.name}.${imageType.name}',
    );
    final File file = File(dockerfile);
    if (!(await file.exists())) {
      throw Exception('Dockerfile does not exist: $dockerfile');
    }
    final String executable = 'docker';
    final List<String> args = [
      'build',
      '-f',
      dockerfile,
      '-t',
      fullImageName,
      '--target',
      'runtime',
    ];
    if (forceOverwriteCache) {
      args.add('--no-cache');
    }
    if (quiet) {
      args.add('--quiet');
    }
    if (imageType == DockerImageType.release) {
      args.add('--build-arg');
      args.add('release=$tag');
    }
    args.add('.'); // context is this directory
    return startCommand(executable, args);
  }
}

String _getDockerfilesPath() {
  return 'tests/npe2e/tools/dockerfiles';
}

String _getFullImageName({
  required final Language language,
  required final DockerImageType imageType,
  required final String tag,
}) {
  return 'atsigncompany/noports_npe2e_${language.name}:$tag';
}
