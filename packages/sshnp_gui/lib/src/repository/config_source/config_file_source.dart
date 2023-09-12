part of 'config_source.dart';

/// [ConfigSource] covariant from a [File]
abstract class ConfigFileSource implements ConfigSource {
  late final String profileName;
  late final String? directory;
  late final String? fileName;
  late final File file;

  SSHNPParams? _params;

  @override
  SSHNPParams get params => _params ?? SSHNPParams.empty();

  ConfigFileSource._(this.profileName, {this.directory, this.fileName})
      : file = File(
          SSHNPParams.getFileName(
            fileName ?? profileName,
            directory: directory,
            replaceSpaces: (fileName == null), // only replace spaces for [profileName] not [fileName]
          ),
        );

  factory ConfigFileSource.sandboxed(String profileName) => SandboxedConfigFileSource(profileName);

  factory ConfigFileSource.imported(String profileName, String directory, {String? fileName}) =>
      ImportedConfigFileSource(profileName, directory, fileName: fileName);

  factory ConfigFileSource.exported(String profileName, String directory, {String? fileName}) =>
      ExportedConfigFileSource(profileName, directory, fileName: fileName);

  @override
  DateTime get lastModified => file.lastModifiedSync();

  @override
  Future<void> create(SSHNPParams params) async {
    if (params.profileName != profileName) {
      throw ArgumentError.value(params.profileName, 'params.profileName', 'must be $profileName');
    }
    await params.toFile(directory: directory);
  }

  @override
  Future<SSHNPParams> read() async {
    try {
      var params = SSHNPParams.fromConfigFile(file.path);
      _params = params;
    } catch (e) {
      _params = null;
    }
    return params;
  }

  @override
  Future<void> update(SSHNPParams params) async {
    params.toFile(directory: directory, overwrite: true);
  }

  @override
  Future<void> delete(SSHNPParams params) async {
    await file.delete();
  }
}

class SandboxedConfigFileSource extends ConfigFileSource {
  SandboxedConfigFileSource(String profileName) : super._(profileName);
}

class ImportedConfigFileSource extends ConfigFileSource {
  /// External Config File Source uses an external, user-selected file path
  ImportedConfigFileSource(String profileName, String directory, {String? fileName})
      : super._(profileName, directory: directory, fileName: fileName);

  // no-op
  @override
  Future<void> create(SSHNPParams params) => throw UnsupportedError('Cannot create an imported config file');
  @override
  Future<void> update(SSHNPParams params) => throw UnsupportedError('Cannot update an imported config file');
  @override
  Future<void> delete(SSHNPParams params) => throw UnsupportedError('Cannot delete an imported config file');
}

class ExportedConfigFileSource extends ConfigFileSource {
  /// Exported Config File Source uses an external, user-selected file path
  ExportedConfigFileSource(String profileName, String directory, {String? fileName})
      : super._(profileName, directory: directory, fileName: fileName);

  // no-op
  @override
  DateTime get lastModified => throw UnsupportedError('Cannot get lastModified of an exported config file');
  @override
  Future<SSHNPParams> read() => throw UnsupportedError('Cannot read an exported config file');
  @override
  Future<void> delete(SSHNPParams params) => throw UnsupportedError('Cannot delete an exported config file');
}
