import 'dart:convert';
import 'dart:io';

import 'package:at_auth/at_auth.dart' show AtKeysPassphraseEnvelopeCodec;
import 'package:at_client/at_client_io.dart' show AtKeys, FileAtKeysIo;
import 'package:noports_config/platform/atsigns.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/privileged_runner.dart';

enum KeysFileStatus {
  absent,
  invalid,
  passphraseNeeded,
  wrongPassphrase,
  readable,
}

class KeysFileInfo {
  const KeysFileInfo(this.status, {this.atsign});
  final KeysFileStatus status;

  /// The atsign the file names, when it could be read.
  final String? atsign;
}

class KeysException implements Exception {
  KeysException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copies .atKeys files into the user's ~/.atsign/keys directory and
/// tightens their permissions. Never overwrites an existing keys file.
class KeysRepository {
  KeysRepository({DaemonPaths? paths}) : _paths = paths;

  final DaemonPaths? _paths;
  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

  /// The atsign a .atKeys file belongs to: from the file itself when it
  /// can be read, otherwise from the conventional `@name_key.atKeys` file
  /// name (a passphrase-protected file says nothing without its
  /// passphrase).
  static String? atsignOf(File file, {String? passPhrase}) {
    final seen = inspectSync(file, passPhrase: passPhrase);
    if (seen.atsign != null) return seen.atsign;
    final name = file.uri.pathSegments.last;
    final m = RegExp(r'^(@?.+)_key\.atKeys$').firstMatch(name);
    return m == null ? null : Atsigns.normalize(m.group(1)!);
  }

  /// Whether [file] is an .atKeys file at_auth can read, or a
  /// passphrase-protected one it could read with the passphrase.
  static bool looksLikeAtKeys(File file, {String? passPhrase}) {
    final seen = inspectSync(file, passPhrase: passPhrase);
    return seen.status == KeysFileStatus.readable ||
        seen.status == KeysFileStatus.passphraseNeeded;
  }

  /// What at_auth makes of [file]: the same parse the daemon applies.
  /// A passphrase envelope is recognised but not opened here (that is
  /// asynchronous); [inspect] does that when a passphrase is given.
  static KeysFileInfo inspectSync(File file, {String? passPhrase}) {
    if (!file.existsSync()) return const KeysFileInfo(KeysFileStatus.absent);
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const KeysFileInfo(KeysFileStatus.invalid);
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const KeysFileInfo(KeysFileStatus.invalid);
    }
    if (const AtKeysPassphraseEnvelopeCodec().isEnvelope(json)) {
      return const KeysFileInfo(KeysFileStatus.passphraseNeeded);
    }
    try {
      final keys = AtKeys.fromJson(json);
      // An empty object parses as a legacy file; one the daemon could
      // authenticate with is what counts.
      if (!keys.holdsAuthenticationMaterial) {
        return const KeysFileInfo(KeysFileStatus.invalid);
      }
      return KeysFileInfo(
        KeysFileStatus.readable,
        atsign: Atsigns.normalize(keys.atsign),
      );
    } catch (_) {
      return const KeysFileInfo(KeysFileStatus.invalid);
    }
  }

  /// [inspectSync], and a protected file is decrypted with [passPhrase]
  /// when one is given, so a wrong passphrase is reported as such.
  static Future<KeysFileInfo> inspect(File file, {String? passPhrase}) async {
    final quick = inspectSync(file);
    if (quick.status != KeysFileStatus.passphraseNeeded ||
        passPhrase == null ||
        passPhrase.isEmpty) {
      return quick;
    }
    try {
      final keys = await FileAtKeysIo(
        filePath: (_) => file.path,
        passPhrase: passPhrase,
      ).read('');
      if (!keys.holdsAuthenticationMaterial) {
        return const KeysFileInfo(KeysFileStatus.invalid);
      }
      return KeysFileInfo(
        KeysFileStatus.readable,
        atsign: Atsigns.normalize(keys.atsign),
      );
    } catch (_) {
      return const KeysFileInfo(KeysFileStatus.wrongPassphrase);
    }
  }

  /// On Linux, the numeric owner of [file], or null elsewhere.
  static int? ownerUid(File file) {
    if (!Platform.isLinux) return null;
    try {
      final r = Process.runSync('stat', ['-c', '%u', file.path]);
      return int.tryParse(r.stdout.toString().trim());
    } catch (_) {
      return null;
    }
  }

  /// Whether the account with [uid] can read [file]: its owner, or a mode
  /// that lets the group or everyone read. Linux only; null when unknown.
  static bool? readableBy(File file, int uid) {
    if (!Platform.isLinux) return null;
    try {
      final r = Process.runSync('stat', ['-c', '%u %a', file.path]);
      final parts = r.stdout.toString().trim().split(' ');
      final owner = int.parse(parts[0]);
      final mode = int.parse(parts[1], radix: 8);
      if (owner == uid) return true;
      return (mode & 0x24) != 0;
    } catch (_) {
      return null;
    }
  }

  /// Copies [source] to the user's keys directory. Returns the destination.
  /// If a different file for the same atsign is already there it is left
  /// alone and a [KeysException] is thrown; the user must move it first.
  Future<File> import(File source, String atsign) async {
    if (!await source.exists()) {
      throw KeysException('File not found: ${source.path}');
    }
    if (!looksLikeAtKeys(source)) {
      throw KeysException(
        '${source.path} is not an .atKeys file at_auth can read.',
      );
    }
    final dest = paths.keysFileFor(atsign);
    if (source.absolute.path == dest.absolute.path) {
      // Already where it belongs; just use it.
      return dest;
    }
    if (await dest.exists()) {
      if (await dest.readAsString() == await source.readAsString()) return dest;
      throw KeysException(
        'Keys for $atsign already exist at ${dest.path}. '
        'Not overwriting them. Move that file away first if you really mean to replace it.',
      );
    }
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
    await restrictPermissions(dest);
    return dest;
  }

  /// The keys should be readable by the owner, the service account and
  /// administrators only. Throws a [StateError] naming the tool's output
  /// when the permissions could not be set; callers decide whether that
  /// is fatal (the daemon still starts with the profile's default ACLs).
  static Future<void> restrictPermissions(File file) async {
    {
      if (Platform.isWindows) {
        // The app runs elevated, but the user's ordinary processes carry a
        // UAC-filtered token where Administrators is deny-only, so the user
        // must be granted explicitly or they lose access to their own keys.
        final user = Platform.environment['USERNAME'];
        final domain = Platform.environment['USERDOMAIN'];
        final r = await Process.run(windowsSystemExe('icacls.exe'), [
          file.path,
          '/inheritance:r',
          '/grant:r',
          '*S-1-5-18:(R)', // LocalSystem, which the service runs as
          '*S-1-5-32-544:(F)', // Administrators
          if (user != null && user.isNotEmpty)
            '${domain != null && domain.isNotEmpty ? '$domain\\' : ''}$user:(F)',
        ]);
        if (r.exitCode != 0) {
          throw StateError(
            'icacls exit ${r.exitCode}: '
            '${(r.stderr.toString().trim().isEmpty ? r.stdout : r.stderr).toString().trim()}',
          );
        }
      } else {
        final r = await Process.run('chmod', ['600', file.path]);
        if (r.exitCode != 0) {
          throw StateError('chmod exit ${r.exitCode}: ${r.stderr}'.trim());
        }
      }
    }
  }

  /// Whether the file the daemon will use for [atsign] exists, taking an
  /// explicit config path into account.
  File? resolve(String? rawAtsign, String? configuredPath) {
    if (configuredPath != null && configuredPath.trim().isNotEmpty) {
      return File(_expandHome(configuredPath.trim()));
    }
    final atsign = Atsigns.normalize(rawAtsign);
    if (atsign == null) return null;
    final managed = paths.keysFileFor(atsign);
    if (managed.existsSync()) return managed;
    final home = paths.serviceHomeDir;
    if (home != null) {
      return File(
        '${home.path}${Platform.pathSeparator}.atsign'
        '${Platform.pathSeparator}keys${Platform.pathSeparator}'
        '${atsign}_key.atKeys',
      );
    }
    return managed;
  }

  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return home + path.substring(1);
  }
}
