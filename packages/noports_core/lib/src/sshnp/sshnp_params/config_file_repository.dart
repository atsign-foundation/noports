import 'dart:io';

import 'package:noports_core/src/common/file_system_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_params/sshnp_params.dart';
import 'package:noports_core/src/sshnp/sshnp_params/sshnp_arg.dart';
import 'package:path/path.dart' as path;

class ConfigFileRepository {
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

  static Future<Directory> createConfigDirectory({String? directory}) async {
    directory ??= getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Iterable<String>> listProfiles({String? directory}) async {
    var profileNames = <String>{};
    directory ??= getDefaultSshnpConfigDirectory(getHomeDirectory()!);
    var files = Directory(directory).list();

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

  static Future<SSHNPParams> getParams(String profileName,
      {String? directory}) async {
    var fileName = await fromProfileName(profileName, directory: directory);
    return SSHNPParams.fromFile(fileName);
  }

  static Future<File> putParams(SSHNPParams params,
      {String? directory, bool overwrite = false}) async {
    if (params.profileName == null || params.profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName =
        await fromProfileName(params.profileName!, directory: directory);
    var file = File(fileName);

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

  static Future<FileSystemEntity> deleteParams(SSHNPParams params,
      {String? directory}) async {
    if (params.profileName == null || params.profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName =
        await fromProfileName(params.profileName!, directory: directory);
    var file = File(fileName);

    var exists = await file.exists();

    if (!exists) {
      throw Exception('Cannot delete ${file.path}, file does not exist');
    }

    return file.delete();
  }

  static Map<String, dynamic> parseConfigFile(String fileName) {
    File file = File(fileName);

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

        SSHNPArg arg = SSHNPArg.fromBashName(key);
        if (arg.name.isEmpty) continue;

        switch (arg.format) {
          case ArgFormat.flag:
            if (value.toLowerCase() == 'true') {
              args[arg.name] = true;
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
