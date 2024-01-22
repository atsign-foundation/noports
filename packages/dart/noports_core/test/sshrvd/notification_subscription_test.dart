import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

void main() {
  test('Test notification subscription regex', () {
    expect(
        RegExp(SshrvdImpl.subscriptionRegex)
            .hasMatch('jagan@test.${Sshrvd.namespace}@jagan'),
        true);
    expect(
        RegExp(SshrvdImpl.subscriptionRegex).hasMatch('${Sshrvd.namespace}@'),
        true);
    expect(
        RegExp(SshrvdImpl.subscriptionRegex)
            .hasMatch('${Sshrvd.namespace}.test@'),
        false);
  });
}
