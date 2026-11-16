import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/platform/atsigns.dart';

void main() {
  test('bare strips the @ and spaces the field draws itself', () {
    expect(Atsigns.bare('@alice'), 'alice');
    expect(Atsigns.bare('@@alice'), 'alice');
    expect(Atsigns.bare('  @ alice '), 'alice');
    expect(Atsigns.bare('alice'), 'alice');
    expect(Atsigns.bare('@'), '');
    expect(Atsigns.bare('colin.constable'), 'colin.constable');
  });

  test('what sshnpd accepts (toAtsign) is what the app accepts', () {
    // Dots are dropped, dashes and emoji are fine, case is folded.
    expect(Atsigns.normalize('@colin.constable'), '@colinconstable');
    expect(Atsigns.normalize('colin-constable'), '@colin-constable');
    expect(Atsigns.normalize('@🛠tools'), '@🛠tools');
    expect(Atsigns.normalize('@CfgDev'), '@cfgdev');
    expect(Atsigns.isValid('@colin.constable'), isTrue);
    expect(Atsigns.isValid('@colin-constable'), isTrue);
    expect(Atsigns.isValid('@🛠tools'), isTrue);
  });

  test('refusals carry at_commons\' reason', () {
    expect(Atsigns.normalize('@'), isNull);
    expect(Atsigns.normalize('no spaces'), isNull);
    expect(Atsigns.normalize('al!ce'), isNull);
    expect(Atsigns.normalize('a@b'), isNull);
    expect(Atsigns.problem('al!ce'), isNotNull);
    expect(Atsigns.problem(''), 'An atsign is required.');
    expect(Atsigns.problem('@alice'), isNull);
  });

  test('55 code points after the @, counted in runes', () {
    expect(Atsigns.isValid('@${'a' * 55}'), isTrue);
    expect(Atsigns.isValid('@${'a' * 56}'), isFalse);
    expect(Atsigns.isValid('@${'🛠' * 55}'), isTrue);
    expect(Atsigns.isValid('@${'🛠' * 56}'), isFalse);
  });

  test('fromInput stores the canonical form, or the typo for validation', () {
    expect(Atsigns.fromInput('alice'), '@alice');
    expect(Atsigns.fromInput('@Alice'), '@alice');
    expect(Atsigns.fromInput('colin.constable'), '@colinconstable');
    expect(Atsigns.fromInput(''), isNull);
    expect(Atsigns.fromInput('@'), isNull);
    expect(Atsigns.fromInput('al!ce'), '@al!ce');
  });
}
