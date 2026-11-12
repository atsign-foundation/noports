import 'dart:async';

import 'package:noports_core/src/common/lookup_slots.dart';
import 'package:test/test.dart';

void main() {
  /// Asks [slots] for a turn for [atSign], noting [label] in [begun] once the
  /// turn comes.
  void ask(LookupSlots slots, String atSign, String label, List<String> begun) {
    slots.acquire(atSign).then((_) => begun.add(label));
  }

  test("One Atsign's lookups are served in the order they asked", () async {
    final slots = LookupSlots(maxConcurrent: 64, maxPerAtSign: 8);
    final begun = <String>[];
    for (var i = 0; i < 20; i++) {
      ask(slots, '@a', 'a$i', begun);
    }
    await pumpEventQueue();
    expect(begun, [
      for (var i = 0; i < 8; i++) 'a$i',
    ], reason: 'its 8 slots go to the first 8 asked');

    for (var i = 0; i < 12; i++) {
      slots.release('@a');
      await pumpEventQueue();
    }

    expect(begun, [for (var i = 0; i < 20; i++) 'a$i']);
  });

  group('Given busy atSigns holding every shared turn', () {
    late LookupSlots slots;
    late List<String> begun;

    setUp(() async {
      slots = LookupSlots(maxConcurrent: 4, maxPerAtSign: 2);
      begun = [];
      for (final busy in ['@b1', '@b2']) {
        for (var i = 0; i < 5; i++) {
          ask(slots, busy, '$busy-$i', begun);
        }
      }
      await pumpEventQueue();
      expect(begun, [
        '@b1-0',
        '@b1-1',
        '@b2-0',
        '@b2-1',
      ], reason: 'the control: each busy atSign has its 2 under way');
    });

    test('when a quiet atSign asks, then it gets the next turn to free, ahead'
        ' of the busy ones that asked before it', () async {
      ask(slots, '@quiet', '@quiet-0', begun);

      slots.release('@b1');
      await pumpEventQueue();

      expect(begun.last, '@quiet-0');
    });

    test('when two quiet atSigns ask, then the one that asked first is served'
        ' first', () async {
      ask(slots, '@x', '@x-0', begun);
      ask(slots, '@y', '@y-0', begun);

      slots.release('@b1');
      await pumpEventQueue();
      expect(begun.last, '@x-0');
      slots.release('@b2');
      await pumpEventQueue();

      expect(begun.sublist(4), ['@x-0', '@y-0']);
    });

    test('when no other atSign is waiting, then a busy one is served as its'
        ' turns free', () async {
      slots.release('@b1');
      await pumpEventQueue();

      expect(begun.last, '@b1-2');
    });
  });

  test('Given an atSign at its own limit, when turns are free, then it waits'
      ' and another atSign is served', () async {
    final slots = LookupSlots(maxConcurrent: 10, maxPerAtSign: 2);
    final begun = <String>[];
    for (var i = 0; i < 3; i++) {
      ask(slots, '@a', '@a-$i', begun);
    }
    ask(slots, '@b', '@b-0', begun);
    await pumpEventQueue();

    expect(begun, ['@a-0', '@a-1', '@b-0']);
    expect(slots.underWay('@a'), 2);
  });

  group('Given every turn taken, @y with 2 lookups under way and @x, served'
      ' after it, with 1, each with another waiting', () {
    late LookupSlots slots;
    late List<String> begun;

    setUp(() async {
      slots = LookupSlots(maxConcurrent: 3, maxPerAtSign: 3);
      begun = [];
      ask(slots, '@y', '@y-0', begun);
      ask(slots, '@y', '@y-1', begun);
      ask(slots, '@x', '@x-0', begun);
      ask(slots, '@x', '@x-1', begun);
      ask(slots, '@y', '@y-2', begun);
      await pumpEventQueue();
      expect(begun, ['@y-0', '@y-1', '@x-0'], reason: 'the control');
    });

    test("when @x's lookup ends, then @x, with fewer under way, is served"
        ' though it was served more recently', () async {
      slots.release('@x');
      await pumpEventQueue();

      expect(begun.last, '@x-1');
    });

    test("when one of @y's lookups ends, then @y, as few under way and served"
        ' less recently, is served', () async {
      slots.release('@y');
      await pumpEventQueue();

      expect(begun.last, '@y-2');
    });
  });

  test(
    'Given a busy atSign whose lookups have all ended, when quiet atSigns'
    ' keep asking, then it is served once each of them has had a turn',
    () async {
      final slots = LookupSlots(maxConcurrent: 2, maxPerAtSign: 2);
      final begun = <String>[];
      ask(slots, '@busy', '@busy-0', begun);
      ask(slots, '@busy', '@busy-1', begun);
      ask(slots, '@busy', '@busy-2', begun);
      await pumpEventQueue();
      ask(slots, '@q1', '@q1-0', begun);
      await pumpEventQueue();

      slots.release('@busy');
      await pumpEventQueue();
      expect(
        begun.last,
        '@q1-0',
        reason: 'the quiet atSign, with none under way, goes first',
      );
      ask(slots, '@q2', '@q2-0', begun);
      slots.release('@busy');
      await pumpEventQueue();
      expect(
        begun.last,
        '@q2-0',
        reason:
            'tied at none under way, the atSign not yet served goes'
            ' first',
      );
      ask(slots, '@q1', '@q1-1', begun);
      slots.release('@q1');
      await pumpEventQueue();

      expect(
        begun.last,
        '@busy-2',
        reason: 'tied with @q1, the busy atSign was served less recently',
      );
    },
  );

  test('Given atSigns tied at none under way, when turns free, then they are'
      ' served in turn, least recently served first', () async {
    final slots = LookupSlots(maxConcurrent: 1, maxPerAtSign: 1);
    final begun = <String>[];
    for (final atSign in ['@a', '@b', '@c']) {
      for (var i = 0; i < 2; i++) {
        ask(slots, atSign, '$atSign-$i', begun);
      }
    }
    await pumpEventQueue();

    for (var i = 0; i < 5; i++) {
      slots.release(begun.last.split('-').first);
      await pumpEventQueue();
    }

    expect(begun, ['@a-0', '@b-0', '@c-0', '@a-1', '@b-1', '@c-1']);
  });

  test(
    'Given every lookup has ended, then nothing is under way or waiting',
    () async {
      final slots = LookupSlots(maxConcurrent: 2, maxPerAtSign: 1);
      final begun = <String>[];
      for (final atSign in ['@a', '@b', '@c']) {
        for (var i = 0; i < 2; i++) {
          ask(slots, atSign, '$atSign-$i', begun);
        }
      }
      await pumpEventQueue();
      expect(slots.idle, isFalse);

      for (var i = 0; i < 6; i++) {
        slots.release(begun[i].split('-').first);
        await pumpEventQueue();
      }

      expect(begun, hasLength(6), reason: 'the control: every lookup began');
      expect(slots.idle, isTrue);
    },
  );

  test('Given 20000 atSigns each with a lookup waiting, when each lookup ends'
      ' as it begins, then all are served within a second', () async {
    final slots = LookupSlots(maxConcurrent: 64, maxPerAtSign: 8);
    final all = Completer<void>();
    var served = 0;
    final Stopwatch took = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      final atSign = '@a$i';
      unawaited(
        slots.acquire(atSign).then((_) {
          slots.release(atSign);
          if (++served == 20000) all.complete();
        }),
      );
    }

    await all.future;

    expect(took.elapsed, lessThan(const Duration(seconds: 1)));
    expect(slots.idle, isTrue);
  });

  test(
    'Given no lookup under way, when one is released, then it is refused',
    () async {
      final slots = LookupSlots(maxConcurrent: 1, maxPerAtSign: 1);
      final begun = <String>[];
      ask(slots, '@a', '@a-0', begun);
      ask(slots, '@b', '@b-0', begun);
      await pumpEventQueue();
      expect(begun, ['@a-0'], reason: 'the control: @b has one waiting');

      expect(() => slots.release('@c'), throwsStateError);
      expect(() => slots.release('@b'), throwsStateError);
      expect(slots.underWay('@b'), 0);
    },
  );
}
