import 'dart:io';

/// Return the command which this program should execute in order to start the
/// sshrv program.
/// - In normal usage, sshnp and sshrv are compiled to exe before use, thus the
/// path is [Platform.resolvedExecutable] but with the last part (`sshnp` in
/// this case) replaced with `sshrv`
String getSshrvCommand() {
  late String sshnpDir;
  List<String> pathList =
      Platform.resolvedExecutable.split(Platform.pathSeparator);
  if (pathList.last == 'sshnp' || pathList.last == 'sshnp.exe') {
    pathList.removeLast();
    sshnpDir = pathList.join(Platform.pathSeparator);

    return '$sshnpDir${Platform.pathSeparator}sshrv';
  } else {
    throw Exception(
        'sshnp is expected to be run as a compiled executable, not via the dart command');
  }
}
