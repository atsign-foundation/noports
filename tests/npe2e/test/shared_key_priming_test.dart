import 'package:npe2e/shared_key_priming.dart';
import 'package:test/test.dart';

void main() {
  group('sharedKeyPairs names each shared key priming creates', () {
    test('Distinct atSigns: when given @a, @b and @c, then it returns every'
        ' ordered pair of two different atSigns, grouped by sharer', () {
      expect(sharedKeyPairs(['@a', '@b', '@c']), [
        (sharer: '@a', receiver: '@b'),
        (sharer: '@a', receiver: '@c'),
        (sharer: '@b', receiver: '@a'),
        (sharer: '@b', receiver: '@c'),
        (sharer: '@c', receiver: '@a'),
        (sharer: '@c', receiver: '@b'),
      ], reason: 'each atSign shares with each other one, once');
    });

    test('A duplicate spelt the same: when @a is given twice beside @b, then'
        ' each shared key between them appears once', () {
      expect(sharedKeyPairs(['@a', '@b', '@a']), [
        (sharer: '@a', receiver: '@b'),
        (sharer: '@b', receiver: '@a'),
      ], reason: 'a repeated atSign adds no pair and no self pair');
    });

    test('A single atSign: when given only @a, then there are no pairs', () {
      expect(
        sharedKeyPairs(['@a']),
        isEmpty,
        reason: 'an atSign shares no key with itself',
      );
    });
  });
}
