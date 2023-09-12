import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/config_manager.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/sshnp_arg.dart';
import 'package:path/path.dart' as path;

String configFileNameToProfileName(String fileName, {bool replaceSpaces = true}) {
  var profileName = path.basenameWithoutExtension(fileName);
  if (replaceSpaces) profileName = profileName.replaceAll('_', ' ');
  return profileName;
}

String profileNameToConfigFileName(String profileName, {String? directory, bool replaceSpaces = true}) {
  var fileName = profileName;
  if (replaceSpaces) fileName = fileName.replaceAll(' ', '_');
  return path.join(
    directory ?? getDefaultSshnpConfigDirectory(getHomeDirectory(throwIfNull: true)!),
    '$fileName.env',
  );
}

const String _keyPrefix = 'profile_';

String atKeyToProfileName(AtKey atKey, {bool replaceSpaces = true}) {
  var profileName = atKey.key!.split('.').first;
  print('r1: $profileName');
  profileName = profileName.replaceFirst(_keyPrefix, '');
  print('r2: $profileName');
  if (replaceSpaces) profileName = profileName.replaceAll('_', ' ');
  print('r3: $profileName');
  return profileName;
}

AtKey profileNameToAtKey(String profileName, {String sharedBy = '', bool replaceSpaces = true}) {
  if (replaceSpaces) profileName = profileName.replaceAll(' ', '_');
  return AtKey.self(
    '$_keyPrefix$profileName',
    namespace: ConfigManager.namespace,
    sharedBy: sharedBy,
  ).build();
}

Future<Directory> createConfigDirectory({String? directory}) async {
  directory ??= getDefaultSshnpConfigDirectory(getHomeDirectory(throwIfNull: true)!);
  var dir = Directory(directory);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<Iterable<String>> listProfilesFromDirectory({String? directory}) async {
  var profileNames = <String>{};

  var homeDirectory = getHomeDirectory(throwIfNull: true)!;
  directory ??= getDefaultSshnpConfigDirectory(homeDirectory);
  var files = Directory(directory).list();

  await files.forEach((file) {
    if (file is! File) return;
    if (path.extension(file.path) != '.env') return;
    if (path.basenameWithoutExtension(file.path).isEmpty) return; // ignore '.env' file - empty profileName
    profileNames.add(configFileNameToProfileName(file.path));
  });
  return profileNames;
}

Map<String, dynamic> parseConfigFile(String fileName) {
  Map<String, dynamic> args = <String, dynamic>{};

  if (path.normalize(fileName).contains('/') || path.normalize(fileName).contains(r'\')) {
    fileName = path.normalize(path.absolute(fileName));
  } else {
    fileName =
        path.normalize(path.absolute(getDefaultSshnpConfigDirectory(getHomeDirectory(throwIfNull: true)!), fileName));
  }

  File file = File(fileName);

  if (!file.existsSync()) {
    throw Exception('Config file does not exist: $fileName');
  }
  try {
    List<String> lines = file.readAsLinesSync();

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
  } on FileSystemException {
    throw Exception('Error reading config file: $fileName');
  } catch (e) {
    throw Exception('Error parsing config file: $fileName');
  }
}

Future<SSHNPParams> sshnpParamsFromFile(String profileName, {String? directory}) async {
  var fileName = profileNameToConfigFileName(profileName, directory: directory);
  return SSHNPParams.fromConfigFile(fileName);
}

Future<File> sshnpParamsToFile(SSHNPParams params, {String? directory, bool overwrite = false}) async {
  if (params.profileName == null || params.profileName!.isEmpty) {
    throw Exception('profileName is null or empty');
  }

  var fileName = profileNameToConfigFileName(params.profileName!, directory: directory);
  var file = File(fileName);

  var exists = await file.exists();

  if (exists && !overwrite) {
    throw Exception('Failed to write config file: ${file.path} already exists');
  }

  // FileMode.write will create the file if it does not exist
  // and overwrite existing files if it does exist
  return file.writeAsString(params.toConfig(), mode: FileMode.write);
}

Future<FileSystemEntity> deleteFile(SSHNPParams params, {String? directory}) async {
  if (params.profileName == null || params.profileName!.isEmpty) {
    throw Exception('profileName is null or empty');
  }

  var fileName = profileNameToConfigFileName(params.profileName!, directory: directory);
  var file = File(fileName);

  var exists = await file.exists();

  if (!exists) {
    throw Exception('Cannot delete ${file.path}, file does not exist');
  }

  return file.delete();
}
