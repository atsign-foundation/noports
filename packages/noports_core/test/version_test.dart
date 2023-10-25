import 'package:noports_core/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('version exists', () {
    expect(packageVersion, isA<String>());
  });
}
