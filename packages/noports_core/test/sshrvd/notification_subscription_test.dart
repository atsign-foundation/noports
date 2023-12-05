import 'package:noports_core/src/sshrvd/sshrvd_impl.dart';
import 'package:noports_core/sshrvd.dart';
import 'package:test/test.dart';
void main() {

  test('Test notification subscription regex', () {
    expect(RegExp(SshrvdImpl.subscriptionRegex).hasMatch('jagan@test.${Sshrvd.namespace}@jagan'), true);
    expect(RegExp(SshrvdImpl.subscriptionRegex).hasMatch('${Sshrvd.namespace}@'), true);
  });
}