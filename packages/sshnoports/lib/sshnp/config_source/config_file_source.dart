part of 'config_source.dart';

/// [ConfigSource] covariant from a [File]
class ConfigFileSource implements ConfigSource {
  late final String profileName;
  late final String? directory;
  late final String? fileName;
  late final File file;

  SSHNPParams? _params;

  @override
  SSHNPParams get params => _params ?? SSHNPParams.empty();

  ConfigFileSource._(this.profileName, {this.directory, this.fileName})
      : file = File(
          profileNameToConfigFileName(
            fileName ?? profileName,
            directory: directory,
            replaceSpaces: (fileName == null), // only replace spaces for [profileName] not [fileName]
          ),
        );
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
      var params = SSHNPParams.fromConfig(file.path);
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
