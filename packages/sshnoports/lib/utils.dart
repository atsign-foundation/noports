import 'dart:io';

import 'package:at_client/at_client.dart';

/// Get the home directory or null if unknown.
String? getHomeDirectory({bool throwIfNull = false}) {
  String? homeDir;
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      homeDir = Platform.environment['HOME'];
    case 'windows':
      homeDir = Platform.environment['USERPROFILE'];
    case 'android':
      // Probably want internal storage.
      homeDir = '/storage/sdcard0';
    case 'ios':
      // iOS doesn't really have a home directory.
    case 'fuchsia':
      // I have no idea.
    default:
      homeDir = null;
  }
  if (throwIfNull && homeDir == null) {
    throw ('\nUnable to determine your home directory: please set environment variable\n\n');
  }
  return homeDir;
}

/// Get the local username or null if unknown
String? getUserName({bool throwIfNull = false}) {
  Map<String, String> envVars = Platform.environment;
  if (Platform.isLinux || Platform.isMacOS) {
    return envVars['USER'];
  } else if (Platform.isWindows) {
    return envVars['USERPROFILE'];
  }
  if (throwIfNull) {
    throw ('\nUnable to determine your username: please set environment variable\n\n');
  }
  return null;
}

Future<bool> fileExists(String file) async {
  bool f = await File(file).exists();
  return f;
}

bool checkNonAscii(String test) {
  var extra = test.replaceAll(RegExp(r'[a-zA-Z0-9_]*'), '');
  if ((extra != '') || (test.length > 15)) {
    return true;
  } else {
    return false;
  }
}

String getDefaultAtKeysFilePath(String homeDirectory, String atSign) {
return '$homeDirectory/.atsign/keys/${atSign}_key.atKeys'
    .replaceAll('/', Platform.pathSeparator);
}

String getDefaultSshDirectory(String homeDirectory) {
return '$homeDirectory/.ssh/'
    .replaceAll('/', Platform.pathSeparator);
}

/// Checks if the provided atSign's atServer has been properly activated with a public RSA key.
/// `atClient` must be authenticated
/// `atSign` is the atSign to check
/// Returns `true`, if the atSign's cloud secondary server has an existing `public:publickey@` in their server, 
/// Returns `false`, if the atSign's cloud secondary *exists*, but does not have an existing `public:publickey@`
/// Throws [AtClientException] if the cloud secondary is invalid or not reachable
Future<bool> atSignIsActivated(final AtClient atClient, String atSign) async {
  final Metadata metadata = Metadata()
    ..isPublic = true
    ..namespaceAware = false;

  final AtKey publicKey = AtKey()
    ..sharedBy = atSign
    ..key = 'publickey'
    ..metadata = metadata;

  try {
    await atClient.get(publicKey);
    return true;
  } catch (e) {
    if(e is AtKeyNotFoundException || (e is AtClientException && e.message.contains("public:publickey") && e.message.contains("does not exist in keystore"))) {
      return false;
    }
    rethrow;
  }
}
