import 'package:at_client/at_client.dart';
import 'package:sshnoports/src/commands/npp_file.dart' show FileBasedPolicy;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Given npp_file rules', () {
    test(
        "a daemon has rules when a user group's daemonAtSigns lists it, and"
        ' otherwise not', () {
      final policy = FileBasedPolicy(loadYaml('''
userGroups:
  engineers:
    userAtSigns: ["@alice"]
    permissions:
      daemonAtSigns: ["@daemon"]
      deviceNames:
        device: ["localhost:22"]
''') as YamlMap);

      expect(policy.hasRulesFor('@daemon'.toAtsign()), isTrue);
      expect(policy.hasRulesFor('@other'.toAtsign()), isFalse);
    });
  });
}
