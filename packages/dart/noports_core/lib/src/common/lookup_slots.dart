import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

/// Turns for lookups to atServers: at most [maxConcurrent] under way in all
/// and [maxPerAtSign] for any one atSign.
///
/// A free turn goes to the waiting lookup whose atSign has the fewest under
/// way; among atSigns with as few, to the one whose last turn, or first ask
/// since it last had nothing pending, came earliest. So an atSign with many
/// lookups waiting cannot hold up another atSign's, which waits for at most
/// one turn for each other atSign with as few under way that asked or was
/// served before it, and the lookups of one atSign are begun in the order
/// they were asked for.
class LookupSlots {
  LookupSlots({required this.maxConcurrent, required this.maxPerAtSign});

  final int maxConcurrent;
  final int maxPerAtSign;

  int _held = 0;
  int _stamps = 0;
  final Map<String, _Turns> _byAtSign = {};
  final SplayTreeSet<_Turns> _ready = SplayTreeSet(_Turns.compare);

  /// Whether no lookup is under way or waiting, and nothing is kept for any
  /// atSign.
  @visibleForTesting
  bool get idle => _held == 0 && _byAtSign.isEmpty && _ready.isEmpty;

  /// How many lookups for [atSign] are under way.
  @visibleForTesting
  int underWay(String atSign) => _byAtSign[atSign]?.underWay ?? 0;

  /// Completes once a lookup for [atSign] may begin. Every completed acquire
  /// is followed by one [release] for the same atSign.
  Future<void> acquire(String atSign) {
    final turn = Completer<void>();
    final _Turns turns = _byAtSign.putIfAbsent(atSign, () => _Turns(_stamps++));
    turns.waiting.add(turn);
    if (turns.waiting.length == 1) _place(turns);
    _dispatch();
    return turn.future;
  }

  /// Ends a lookup for [atSign] that [acquire] began.
  void release(String atSign) {
    final _Turns? turns = _byAtSign[atSign];
    if (turns == null || turns.underWay < 1) {
      throw StateError('No lookup for $atSign is under way');
    }
    _unplace(turns);
    turns.underWay--;
    _held--;
    if (turns.underWay == 0 && turns.waiting.isEmpty) {
      _byAtSign.remove(atSign);
    } else {
      _place(turns);
    }
    _dispatch();
  }

  // NOTE: an atSign's place in [_ready] is fixed by its fields, so it leaves
  // [_ready] before any of them changes and is placed again afterwards
  void _place(_Turns turns) {
    if (turns.waiting.isNotEmpty && turns.underWay < maxPerAtSign) {
      _ready.add(turns);
      turns.placed = true;
    }
  }

  void _unplace(_Turns turns) {
    if (turns.placed) {
      _ready.remove(turns);
      turns.placed = false;
    }
  }

  void _dispatch() {
    while (_held < maxConcurrent && _ready.isNotEmpty) {
      final _Turns next = _ready.first;
      _unplace(next);
      final Completer<void> turn = next.waiting.removeFirst();
      next.underWay++;
      next.stamp = _stamps++;
      _held++;
      _place(next);
      turn.complete();
    }
  }
}

/// One atSign's lookups: those waiting, in the order asked for, and how many
/// are under way.
class _Turns {
  _Turns(this.stamp);

  final Queue<Completer<void>> waiting = Queue();
  int underWay = 0;

  /// When this atSign last had a turn, or first asked since it last had
  /// nothing pending.
  int stamp;
  bool placed = false;

  /// Fewest under way first, then the earliest [stamp], which no two
  /// atSigns share.
  static int compare(_Turns a, _Turns b) {
    final int byUnderWay = a.underWay.compareTo(b.underWay);
    if (byUnderWay != 0) return byUnderWay;
    return a.stamp.compareTo(b.stamp);
  }
}
