import 'dart:async';

import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:path/path.dart' as path;
import 'package:posix/posix.dart' show PosixException, chmod;

class LocalSshKeyUtil implements AtSshKeyUtil {
  static final Map<String, AtSshKeyPair> _keyPairCache = {};

  @visibleForTesting
  final FileSystem fs;

  final String homeDirectory;
  late final String sshHomeDirectory;
  late final String sshnpHomeDirectory;
  bool cacheKeys;

  LocalSshKeyUtil({
    String? homeDirectory,
    this.cacheKeys = true,
    @visibleForTesting this.fs = const LocalFileSystem(),
  }) : homeDirectory = homeDirectory ?? getHomeDirectory(throwIfNull: true)! {
    sshHomeDirectory = path.normalize('${this.homeDirectory}/.ssh/');
    sshnpHomeDirectory = path.normalize('${this.homeDirectory}/.sshnp/');

    if (!fs.directory(sshHomeDirectory).existsSync()) {
      fs.directory(sshHomeDirectory).createSync(recursive: true);
    }
    if (!fs.directory(sshnpHomeDirectory).existsSync()) {
      fs.directory(sshnpHomeDirectory).createSync(recursive: true);
    }
    if (!Platform.isWindows) {
      try {
        chmod(sshHomeDirectory, '700');
        chmod(sshnpHomeDirectory, '700');
      } on PosixException catch (e, s) {
        throw SshnpError(e.toString(), error: e, stackTrace: s);
      } catch (_) {
        rethrow;
      }
    }
  }

  bool get isValidPlatform =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  String get username => getUserName(throwIfNull: true)!;

  List<File> _filesFromIdentifier({required String identifier}) {
    return [
      fs.file(path.normalize(identifier)),
      fs.file(path.normalize('$identifier.pub')),
    ];
  }

  @override
  Future<List<File>> addKeyPair({
    required AtSshKeyPair keyPair,
    String? identifier,
  }) async {
    var files = _filesFromIdentifier(
      identifier: identifier ?? keyPair.identifier,
    );
    await Future.wait([
      files[0].create(recursive: true),
      files[1].create(recursive: true),
    ]).catchError((e) => throw e);

    await Future.wait([
      files[0].writeAsString(keyPair.privateKeyContents),
      files[1].writeAsString(keyPair.publicKeyContents),
    ]).catchError((e) => throw e);

    if (!Platform.isWindows) {
      try {
        chmod(files[0].path, '600');
        chmod(files[1].path, '644');
      } on PosixException catch (e, s) {
        throw SshnpError(e.toString(), error: e, stackTrace: s);
      } catch (_) {
        rethrow;
      }
    }

    return files;
  }

  @override
  Future<AtSshKeyPair> getKeyPair({
    required String identifier,
    String? passphrase,
  }) async {
    if (_keyPairCache.containsKey((identifier))) {
      return _keyPairCache[(identifier)]!;
    }
    var files = _filesFromIdentifier(identifier: identifier);
    var keyPair = AtSshKeyPair.fromPem(
      await files[0].readAsString(),
      identifier: identifier,
      passphrase: passphrase,
    );

    if (cacheKeys) {
      _keyPairCache[identifier] = keyPair;
    }
    return keyPair;
  }

  @override
  Future<List<FileSystemEntity>> deleteKeyPair({
    required String identifier,
  }) async {
    var files = _filesFromIdentifier(identifier: identifier);

    return Future.wait(files.map((f) => f.delete())).catchError((e) => throw e);
  }
}
