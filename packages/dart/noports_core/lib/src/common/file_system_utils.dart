import 'package:noports_core/src/common/io_types.dart';
import 'package:path/path.dart' as path;

/// $homeDirectory/.atsign/storage/$atSign/.$progName/$uniqueID
String standardAtClientStoragePath({
  required String homeDirectory,
  required String atSign,
  required String progName, // e.g. npt, sshnp, sshnpd, srvd etc
  required String uniqueID,
}) {
  return path.normalize('$homeDirectory'
      '/.atsign'
      '/storage'
      '/$atSign'
      '/.$progName'
      '/$uniqueID');
}

/// Get the home directory or null if unknown.
String? getHomeDirectory({bool throwIfNull = false}) {
  String? homeDir;
  String envVarName = '';
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      envVarName = 'HOME';
      homeDir = Platform.environment[envVarName];
      break;
    case 'windows':
      envVarName = 'USERPROFILE';
      homeDir = Platform.environment[envVarName];
      break;
    default:
      // ios and fuchsia to use the ApplicationSupportDirectory
      homeDir = null;
      if (throwIfNull) {
        throw ('Unable to determine home directory on platform ${Platform.operatingSystem}');
      }
      break;
  }
  if (throwIfNull && homeDir == null) {
    throw ('Unable to determine your home directory: please set $envVarName environment variable');
  }
  return homeDir;
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  String? userName;
  String envVarName = '';
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      envVarName = 'USER';
      userName = envVars[envVarName];
      break;
    case 'windows':
      envVarName = 'USERNAME';
      userName = envVars[envVarName];
      break;
    default:
      userName = null;
      if (throwIfNull) {
        throw ('Unable to determine username on platform ${Platform.operatingSystem}');
      }
      break;
  }
  if (throwIfNull && userName == null) {
    throw ('Unable to determine your username: please set environment variable $envVarName');
  }
  return userName;
}

String getDefaultAtKeysFilePath(String homeDirectory, String? atSign) {
  if (atSign == null) return '';
  return path.normalize('$homeDirectory/.atsign/keys/${atSign}_key.atKeys');
}
