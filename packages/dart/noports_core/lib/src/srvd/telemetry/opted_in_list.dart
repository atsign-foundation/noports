import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:at_client/at_client.dart';

/// The Atsigns that have opted in, as the collector last confirmed them at
/// [builtAt].
class OptedInList {
  final DateTime builtAt;
  final Set<String> atsigns;

  OptedInList({required this.builtAt, required Set<String> atsigns})
      : atsigns = Set.unmodifiable(atsigns);
}

/// Somewhere the opted-in list is read from. [read] throws when the list
/// cannot be read whole and consistent.
abstract interface class OptedInListSource {
  Future<OptedInList> read();
}

/// The opted-in list as the collector Atsign publishes it: a manifest item
/// naming how many chunk items hold the list, and the chunks, each the value
/// an AtCollection stores for an item, read through [readItem] by item id.
class CollectionOptedInListSource implements OptedInListSource {
  static const String namespace = 'optedin.at_telemetry';
  static const String manifestId = 'manifest';
  static const int maxChunkSize = 1000;
  static const int maxChunks = 10000;
  static const Duration maxClockSkew = Duration(minutes: 5);

  static String chunkId(int index) =>
      'chunk-${index.toString().padLeft(4, '0')}';

  CollectionOptedInListSource({
    required this.readItem,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.timestamp;

  /// The stored value of the item with this id, or null when there is none.
  final Future<String?> Function(String itemId) readItem;
  final DateTime Function() _now;

  /// A source reading the copies [collector] shares with the [atClient]'s
  /// own Atsign, each looked up afresh through its atServer.
  factory CollectionOptedInListSource.forCollector({
    required AtClient atClient,
    required String collector,
  }) =>
      CollectionOptedInListSource(
        readItem: (String itemId) async {
          final AtKey key = AtKey()
            ..key = itemId
            ..namespace = namespace
            ..sharedBy = collector
            ..sharedWith = atClient.getCurrentAtSign();
          try {
            final AtValue value = await atClient.get(
              key,
              getRequestOptions: GetRequestOptions()
                ..useRemoteAtServer = true
                ..bypassCache = true,
            );
            return value.value is String ? value.value as String : null;
          } on AtKeyNotFoundException {
            return null;
          }
        },
      );

  @override
  Future<OptedInList> read() async {
    final Map<String, Object?> manifest = _object(
      await _item(manifestId),
      const {'builtAt', 'chunks', 'window'},
      manifestId,
    );
    final Object? builtAtText = manifest['builtAt'];
    final Object? chunks = manifest['chunks'];
    if (builtAtText is! String || chunks is! int || manifest['window'] is! String) {
      throw const FormatException('the manifest has the wrong shape');
    }
    final DateTime builtAt = DateTime.parse(builtAtText).toUtc();
    if (builtAt.isAfter(_now().add(maxClockSkew))) {
      throw FormatException('the manifest was built in the future: $builtAtText');
    }
    if (chunks < 0 || chunks > maxChunks) {
      throw FormatException('the manifest names $chunks chunks');
    }
    final Set<String> atsigns = {};
    for (int index = 0; index < chunks; index++) {
      final String id = chunkId(index);
      final Object? entries =
          _object(await _item(id), const {'atsigns'}, id)['atsigns'];
      if (entries is! List<Object?> || entries.length > maxChunkSize) {
        throw FormatException('$id does not hold a list of at most '
            '$maxChunkSize Atsigns');
      }
      for (final Object? entry in entries) {
        if (entry is! String || !_canonical(entry)) {
          throw FormatException('$id holds an entry that is not a canonical'
              ' Atsign: $entry');
        }
        atsigns.add(entry);
      }
    }
    return OptedInList(builtAt: builtAt, atsigns: atsigns);
  }

  /// The object an item holds: the `obj` of the AtCollection item's value.
  Future<Object?> _item(String id) async {
    final String? stored = await readItem(id);
    if (stored == null) {
      throw StateError('the opted-in list has no item $id');
    }
    final Object? decoded = jsonDecode(stored);
    if (decoded is! Map<String, Object?> || !decoded.containsKey('obj')) {
      throw FormatException('$id is not a collection item');
    }
    return decoded['obj'];
  }

  static Map<String, Object?> _object(Object? value, Set<String> keys, String id) {
    if (value is! Map<String, Object?> ||
        value.length != keys.length ||
        !value.keys.every(keys.contains)) {
      throw FormatException('$id must be an object with exactly $keys');
    }
    return value;
  }

  static bool _canonical(String value) {
    try {
      return value.toAtsign() == value;
    } catch (_) {
      return false;
    }
  }
}

/// Keeps the latest good opted-in list from [source]: read at [start] and
/// every [interval] (with ±10% jitter), retried with backoff from
/// [firstRetryFrom] doubling to [firstRetryTo] until the first good read,
/// and from [laterRetryFrom] up to the next scheduled read after that. A read
/// that fails keeps the list already held. A list older than [maxAge] is
/// not [usable]; the change is warned about once, then once an hour while it
/// lasts.
class OptedInListPoller {
  static const Duration defaultInterval = Duration(minutes: 15);
  static const Duration defaultMaxAge = Duration(hours: 24);
  static const Duration staleWarningInterval = Duration(hours: 1);

  OptedInListPoller({
    required this.source,
    this.interval = defaultInterval,
    this.maxAge = defaultMaxAge,
    this.firstRetryFrom = const Duration(seconds: 5),
    this.firstRetryTo = const Duration(minutes: 5),
    this.laterRetryFrom = const Duration(seconds: 30),
    required void Function(String message) onWarning,
    DateTime Function()? now,
    Random? random,
  })  : _onWarning = onWarning,
        _now = now ?? DateTime.timestamp,
        _random = random ?? Random();

  final OptedInListSource source;
  final Duration interval;
  final Duration maxAge;
  final Duration firstRetryFrom;
  final Duration firstRetryTo;
  final Duration laterRetryFrom;
  final void Function(String message) _onWarning;
  final DateTime Function() _now;
  final Random _random;

  OptedInList? _list;
  Timer? _timer;
  bool _stopped = false;
  DateTime? _staleWarnedAt;
  Duration? _retry;
  final Completer<void> _firstGood = Completer<void>();

  /// The list held, usable or not.
  OptedInList? get list => _list;

  /// Completes at the first good read.
  Future<void> get firstGoodRead => _firstGood.future;

  /// How long ago the list held was built; null when none is held.
  Duration? get age => _list == null ? null : _now().difference(_list!.builtAt);

  /// Whether a list is held and is no older than [maxAge].
  bool get usable {
    final Duration? a = age;
    final bool ok = a != null && a <= maxAge;
    if (_list != null && !ok) {
      final DateTime now = _now();
      if (_staleWarnedAt == null ||
          now.difference(_staleWarnedAt!) >= staleWarningInterval) {
        _staleWarnedAt = now;
        _onWarning('The opted-in list was built ${a!.inMinutes} minutes ago,'
            ' over the ${maxAge.inHours} hour limit, so new sessions are not'
            ' reported until a newer list is read');
      }
    } else if (ok) {
      _staleWarnedAt = null;
    }
    return ok;
  }

  /// Whether [atsign] is on a usable list.
  bool listed(String atsign) => usable && _list!.atsigns.contains(atsign);

  /// Reads now, then keeps reading on schedule until [stop].
  void start() => unawaited(_read());

  /// Stops reading.
  void stop() {
    _stopped = true;
    _timer?.cancel();
  }

  Future<void> _read() async {
    if (_stopped) return;
    try {
      final OptedInList read = await source.read();
      if (_stopped) return;
      _list = read;
      _retry = null;
      if (!_firstGood.isCompleted) _firstGood.complete();
      usable;
      _schedule(_jittered(interval));
    } catch (e) {
      if (_stopped) return;
      final bool before = _list == null;
      final Duration from = before ? firstRetryFrom : laterRetryFrom;
      final Duration to = before ? firstRetryTo : interval;
      final Duration next = _retry == null
          ? from
          : Duration(
              milliseconds: min(_retry!.inMilliseconds * 2, to.inMilliseconds));
      _retry = next;
      _onWarning('Could not read the opted-in list ($e); keeping'
          '${before ? ' nothing' : ' the list held'} and retrying in'
          ' ${next.inSeconds}s');
      _schedule(next);
    }
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    if (_stopped) return;
    _timer = Timer(after, () => unawaited(_read()));
  }

  Duration _jittered(Duration d) {
    final double factor = 0.9 + _random.nextDouble() * 0.2;
    return Duration(microseconds: (d.inMicroseconds * factor).round());
  }
}
