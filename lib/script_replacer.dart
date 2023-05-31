import 'dart:io';

/// Usage exmaple
/// ```dart
/// Script script = Script('../test.txt');
/// script.replace('<name>', '@jeremy');
/// script.writeAs('../test2.txt');
/// ```
class Script {
  final String _path;
  late File _file;
  late String _contents;

  Script(this._path) {
    _file = File(_path);
    _contents = _file.readAsStringSync();
  }

  String get path => _path;

  String get contents => _contents;

  // replace all instances of regex with replacement in this contents
  Future<bool> replace(String regex, String replacement) async {
    bool success = false;
    try {
      _contents = _contents.replaceAll(RegExp(regex), replacement);
      success = true;
    } catch (err) {
      stderr.writeln('Script.replace: ${err.toString()}');
      rethrow;
    }
    return success;
  }

  Future<bool> writeAs(String path) async {
    // write _contents to _path
    bool success = false;
    File newFile = File(path);
    try {
      await newFile.writeAsString(_contents, mode: FileMode.write);
      success = true;
    } catch (err) {
      stderr.writeln('Script.writeAs: ${err.toString()}');
      rethrow;
    }
    return success;
  }
}
