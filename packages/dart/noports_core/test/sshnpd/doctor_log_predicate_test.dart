@TestOn('mac-os')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:math';

import 'package:noports_core/src/sshnpd/doctor/utils/platform_utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final bool hasCompiler =
      Process.runSync('cc', ['--version'], runInShell: true).exitCode == 0;

  test("the doctor's macOS log predicate finds sshnpd run as atsc, or under "
      'its own name', () async {
    final Directory dir = Directory(
      Directory.systemTemp
          .createTempSync('doctor_log_predicate')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final String source = path.join(dir.path, 'emit.c');
    File(source).writeAsStringSync(
      '#include <syslog.h>\n'
      'int main(int argc, char **argv) {\n'
      '  syslog(LOG_ERR, "%s", argv[1]);\n'
      '  return 0;\n'
      '}\n',
    );
    final String marker = 'doctor-log-predicate-${Random().nextInt(1 << 32)}';
    const List<String> processes = ['atsc', 'sshnpd', 'other'];
    for (final String name in processes) {
      final String program = path.join(dir.path, name);
      final compiled = await Process.run('cc', ['-o', program, source]);
      expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
      final logged = await Process.run(program, ['$name $marker']);
      expect(logged.exitCode, 0, reason: '${logged.stderr}');
    }

    /// The processes whose entry carrying the marker [predicate] matches.
    Future<Set<String>> found(String predicate) async {
      final result = await Process.run('log', [
        'show',
        '--last',
        '5m',
        '--style',
        'syslog',
        '--predicate',
        '($predicate) AND composedMessage CONTAINS "$marker"',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return {
        for (final String name in processes)
          if ((result.stdout as String).contains('$name $marker')) name,
      };
    }

    Set<String> logged = {};
    for (int i = 0; i < 10 && logged.length < processes.length; i++) {
      if (i > 0) await Future.delayed(Duration(seconds: 2));
      logged = await found('TRUEPREDICATE');
    }
    expect(logged, processes.toSet());

    expect(await found(MacOSUtils.logPredicate('sshnpd')), {'atsc', 'sshnpd'});
  }, skip: hasCompiler ? false : 'needs a C compiler to log as atsc');
}
