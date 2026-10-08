import 'dart:io';

String getOsString() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isWindows) return 'windows';
  throw Exception('Unsupported platform: ${Platform.operatingSystem}');
}

String getArchString() {
  final String arch = Platform.version.contains('x64') ? 'x64' : 'arm64';
  return arch;
}
