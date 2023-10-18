import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('', () {
    test('ConfigFileRepository.atKeyFromProfileName test', () async {
      String profileName = 'myProfileName';

      expect(ConfigFileRepository.getDefaultSshnpConfigDirectory(getHomeDirectory()!), isA<String>());
      expect(ConfigFileRepository.fromProfileName(profileName), isA<Future<String>>());
      expect(ConfigFileRepository.fromProfileName(profileName), completes);
      expect(
        await ConfigFileRepository.fromProfileName(profileName, basenameOnly: false),
        equals(path.join(getHomeDirectory()!, '.sshnp', 'config', '$profileName.env')),
      );
      expect(await ConfigFileRepository.fromProfileName(profileName, basenameOnly: true), equals('$profileName.env'));
    });

    group('[depends on ConfigFileRepository.atKeyFromProfileName]', () {
      // TODO implement these tests with mock file system
      // not a priority, so skipping for now
    });
  });
}
