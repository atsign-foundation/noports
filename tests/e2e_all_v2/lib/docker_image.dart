import 'dart:io';

import 'package:e2e_all_v2/language.dart';

enum DockerImageType {
  release, // "v5.9.4", "v5.11.3", "c0.0.1"
  branch, // "trunk", *commithash*
  current, // represents the current code on the machine (latest)
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
