import 'package:noports_core/src/common/io_types.dart';
import 'package:path/path.dart' as path;

/// Get the home directory or null if unknown.
String? getHomeDirectory({bool throwIfNull = false}) {
  String? homeDir;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      homeDir = Platform.environment['HOME'];
      break;
    case 'windows':
      homeDir = Platform.environment['USERPROFILE'];
      break;
    default:
      // ios and fuchsia to use the ApplicationSupportDirectory
      homeDir = null;
      break;
  }
  if (throwIfNull && homeDir == null) {
    throw ('Unable to determine your username: please set environment variable');
  }
  return homeDir;
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  String? userName;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      userName = envVars['USER'];
      break;
    case 'windows':
      userName = envVars['USERNAME'];
      break;
    default:
      userName = null;
      break;
  }
  if (throwIfNull && userName == null) {
    throw ('Unable to determine your username: please set environment variable');
  }
  return userName;
}

String getDefaultAtKeysFilePath(String homeDirectory, String? atSign) {
  if (atSign == null) return '';
  return path.normalize('$homeDirectory/.atsign/keys/${atSign}_key.atKeys');
}
