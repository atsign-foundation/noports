import 'package:meta/meta.dart';
import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/sshnp/models/sshnp_params.dart';
import 'package:noports_core/src/sshnp/models/sshnp_arg.dart';
import 'package:path/path.dart' as path;

class ConfigFileRepository {
  static String getDefaultSshnpConfigDirectory(String homeDirectory) {
    return path.normalize('$homeDirectory/.sshnp/config');
  }

  static String toProfileName(String fileName, {bool replaceSpaces = true}) {
    var profileName = path.basenameWithoutExtension(fileName);
    if (replaceSpaces) profileName = profileName.replaceAll('_', ' ');
    return profileName;
  }

  static Future<String> fromProfileName(String profileName,
      {String? directory,
      bool replaceSpaces = true,
      bool basenameOnly = false}) async {
    var fileName = profileName;
    if (replaceSpaces) fileName = fileName.replaceAll(' ', '_');
    final basename = '$fileName.env';
    if (basenameOnly) return basename;
    return path.join(
      directory ?? getDefaultSshnpConfigDirectory(getHomeDirectory()!),
      basename,
    );
  }

  static Future<Directory> createConfigDirectory({
    String? directory,
    @visibleForTesting FileSystem fs = const LocalFileSystem(),
  }) async {
    directory ??= getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var dir = fs.directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Iterable<String>> listProfiles({
    String? directory,
    @visibleForTesting FileSystem fs = const LocalFileSystem(),
  }) async {
    var profileNames = <String>{};
    directory ??= getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var files = fs.directory(directory).list();

    await files.forEach((file) {
      if (file is! File) return;
      if (path.extension(file.path) != '.env') return;
      if (path.basenameWithoutExtension(file.path).isEmpty) {
        // ignore '.env' file - empty profileName
        return;
      }
      profileNames.add(toProfileName(file.path));
    });
    return profileNames;
  }

  static Future<SshnpParams> getParams(String profileName,
      {String? directory}) async {
    var fileName = await fromProfileName(profileName, directory: directory);
    return SshnpParams.fromFile(fileName);
  }

  static Future<File> putParams(
    SshnpParams params, {
    String? directory,
    bool overwrite = false,
    @visibleForTesting FileSystem fs = const LocalFileSystem(),
  }) async {
    if (params.profileName == null || params.profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName =
        await fromProfileName(params.profileName!, directory: directory);
    var file = fs.file(fileName);

    var exists = await file.exists();

    if (exists && !overwrite) {
      throw Exception(
          'Failed to write config file: ${file.path} already exists');
    }

    // FileMode.write will create the file if it does not exist
    // and overwrite existing files if it does exist
    return file.writeAsString(
      params.toConfigLines().join('\n'),
      mode: FileMode.write,
    );
  }

  static Future<FileSystemEntity> deleteParams(
    SshnpParams params, {
    String? directory,
    @visibleForTesting FileSystem fs = const LocalFileSystem(),
  }) async {
    if (params.profileName == null || params.profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName =
        await fromProfileName(params.profileName!, directory: directory);
    var file = fs.file(fileName);

    var exists = await file.exists();

    if (!exists) {
      throw Exception('Cannot delete ${file.path}, file does not exist');
    }

    return file.delete();
  }

  static Map<String, dynamic> parseConfigFile(
    String fileName, {
    @visibleForTesting FileSystem fs = const LocalFileSystem(),
  }) {
    File file = fs.file(fileName);

    if (!file.existsSync()) {
      throw Exception('Config file does not exist: $fileName');
    }
    try {
      List<String> lines = file.readAsLinesSync();
      return parseConfigFileContents(lines);
    } on FileSystemException {
      throw Exception('Error reading config file: $fileName');
    }
  }

  static Map<String, dynamic> parseConfigFileContents(List<String> lines) {
    Map<String, dynamic> args = <String, dynamic>{};

    try {
      for (String line in lines) {
        if (line.startsWith('#')) continue;

        var parts = line.split('=');
        if (parts.length != 2) continue;

        var key = parts[0].trim();
        var value = parts[1].trim();

        SshnpArg arg = SshnpArg.fromBashName(key);
        if (arg.name.isEmpty) continue;
        if (!ParserType.configFile.shouldParse(arg.parseWhen)) continue;
        switch (arg.format) {
          case ArgFormat.flag:
            if (value.toLowerCase() == 'true') {
              args[arg.name] = true;
            } else {
              args[arg.name] = false;
            }
            continue;
          case ArgFormat.multiOption:
            var values = value.split(',');
            args.putIfAbsent(arg.name, () => <String>[]);
            for (String val in values) {
              if (val.isEmpty) continue;
              args[arg.name].add(val);
            }
            continue;
          case ArgFormat.option:
            if (value.isEmpty) continue;
            if (arg.type == ArgType.integer) {
              args[arg.name] = int.tryParse(value);
            } else {
              args[arg.name] = value;
            }
            continue;
        }
      }
      return args;
    } catch (e) {
      throw Exception('Error parsing config file');
    }
  }
}
