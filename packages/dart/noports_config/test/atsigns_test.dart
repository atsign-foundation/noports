import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/platform/atsigns.dart';

void main() {
  test('bare strips the @ and spaces the field draws itself', () {
    expect(Atsigns.bare('@alice'), 'alice');
    expect(Atsigns.bare('@@alice'), 'alice');
    expect(Atsigns.bare('  @ alice '), 'alice');
    expect(Atsigns.bare('alice'), 'alice');
    expect(Atsigns.bare('@'), '');
  });

  test('fromInput stores @name lowercased, or null when empty', () {
    expect(Atsigns.fromInput('alice'), '@alice');
    expect(Atsigns.fromInput('@Alice'), '@alice');
    expect(Atsigns.fromInput(''), isNull);
    expect(Atsigns.fromInput('@'), isNull);
    // Kept, so validation can name the typo rather than silently dropping it.
    expect(Atsigns.fromInput('al!ce'), '@al!ce');
  });

  test('normalize', () {
    expect(Atsigns.normalize('cfgdev'), '@cfgdev');
    expect(Atsigns.normalize('@CfgDev'), '@cfgdev');
    expect(Atsigns.normalize('@'), isNull);
    expect(Atsigns.normalize('no spaces'), isNull);
  });
}
