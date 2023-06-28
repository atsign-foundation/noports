import 'package:sshnoports/sshnp.dart';
import 'package:test/test.dart';

void main() {
  test('sshnoports', () async {
    const List<String> args = [
      '-f',
      '@jeremy_0',
      '-t',
      '@soccer0',
      '-s',
      'id_ed25519.pub',
      '-h',
      '@rv_am',
      '-d',
      'docker',
      '-v'
    ];

    SSHNP sshnp = await SSHNP.fromCommandLineArgs(args);
    await sshnp.init();
    await sshnp.run();
  });
}
