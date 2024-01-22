import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

void main() {
  test('Test notification subscription regex', () {
    expect(
        RegExp(SrvdImpl.subscriptionRegex)
            .hasMatch('jagan@test.${Srvd.namespace}@jagan'),
        true);
    expect(RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}@'),
        true);
    expect(
        RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}.test@'),
        false);
  });
}
