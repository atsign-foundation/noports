import 'dart:convert';
import 'dart:io';

import 'package:at_utils/at_utils.dart';
import 'package:noports_config/platform/daemon_paths.dart';

class KeysException implements Exception {
  KeysException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copies .atKeys files into the daemon's managed keys directory and
/// tightens their permissions.
class KeysRepository {
  KeysRepository({DaemonPaths? paths}) : _paths = paths;

  final DaemonPaths? _paths;
  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

  /// The atSign a .atKeys file belongs to. Files written by the atPlatform
  /// tooling carry it as the one JSON key that starts with '@'; otherwise
  /// fall back to the conventional `@name_key.atKeys` file name.
  static String? atsignOf(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map) {
        for (final k in json.keys) {
          if (k is String && k.startsWith('@')) return AtUtils.fixAtSign(k);
        }
      }
    } catch (_) {
      // fall through to the file name
    }
    final name = file.uri.pathSegments.last;
    final m = RegExp(r'^(@?[a-zA-Z0-9_]+)_key\.atKeys$').firstMatch(name);
    return m == null ? null : AtUtils.fixAtSign(m.group(1)!);
  }

  static bool looksLikeAtKeys(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is Map &&
          json.containsKey('aesPkamPrivateKey') &&
          json.containsKey('selfEncryptionKey');
    } catch (_) {
      return false;
    }
  }

  /// Copies [source] to the managed directory. Returns the destination.
  Future<File> import(File source, String atsign) async {
    if (!await source.exists()) {
      throw KeysException('File not found: ${source.path}');
    }
    if (!looksLikeAtKeys(source)) {
      throw KeysException('${source.path} is not an .atKeys file.');
    }
    final dest = paths.keysFileFor(atsign);
    await dest.parent.create(recursive: true);
    if (source.absolute.path != dest.absolute.path) {
      await source.copy(dest.path);
    }
    await restrictPermissions(dest);
    return dest;
  }

  /// Best effort: the keys should be readable by the service account and
  /// administrators only.
  static Future<void> restrictPermissions(File file) async {
    try {
      if (Platform.isWindows) {
        await Process.run('icacls', [
          file.path,
          '/inheritance:r',
          '/grant:r',
          '*S-1-5-18:(R)', // SYSTEM
          '*S-1-5-32-544:(F)', // Administrators
        ]);
      } else {
        await Process.run('chmod', ['600', file.path]);
      }
    } catch (_) {
      // Not fatal; the daemon will still start.
    }
  }

  /// Whether the file the daemon will use for [atsign] exists, taking an
  /// explicit config path into account.
  File? resolve(String? atsign, String? configuredPath) {
    if (configuredPath != null && configuredPath.trim().isNotEmpty) {
      return File(_expandHome(configuredPath.trim()));
    }
    if (atsign == null || atsign.isEmpty) return null;
    final managed = paths.keysFileFor(atsign);
    if (managed.existsSync()) return managed;
    final home = paths.serviceHomeDir;
    if (home != null) {
      return File(
        '${home.path}${Platform.pathSeparator}.atsign'
        '${Platform.pathSeparator}keys${Platform.pathSeparator}'
        '${AtUtils.fixAtSign(atsign)}_key.atKeys',
      );
    }
    return managed;
  }

  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return home + path.substring(1);
  }
}
