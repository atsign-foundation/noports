import 'dart:async';
import 'dart:isolate';

import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:socket_connector/socket_connector.dart';

/// How often a worker reports a running session's progress to main.
const Duration defaultProgressInterval = Duration(minutes: 15);

/// Reports one session's connections to the main isolate: `newConnection`
/// when a pair forms, `connectionClosed` once both its sides are destroyed,
/// `progress` every [progressInterval] from the first pair, and
/// `sessionComplete` from [complete], after every close has been reported or
/// the bound has passed. Every time is taken here, at the event.
class ConnectionTracker {
  ConnectionTracker({
    required this.sessionId,
    required this.toMain,
    required Stream<Connection> opened,
    required Stream<Connection> closed,
    required this.stats,
    this.closeFlushTimeout = SocketConnector.defaultCloseFlushTimeout,
    this.progressInterval = defaultProgressInterval,
    AtSignLogger? logger,
  }) : logger = logger ?? AtSignLogger(' srvd / ConnectionTracker $sessionId ') {
    _openedSub = opened.listen(_onOpened);
    _closedSub = closed.listen(_onClosed, onDone: _closedDone.complete);
  }

  final String sessionId;
  final SendPort toMain;

  /// The connector's stats, carried on the first `newConnection` and on
  /// `sessionComplete`.
  final Stats Function() stats;

  final Duration closeFlushTimeout;
  final Duration progressInterval;
  final AtSignLogger logger;

  late final StreamSubscription<Connection> _openedSub;
  late final StreamSubscription<Connection> _closedSub;
  final Completer<void> _closedDone = Completer<void>();
  final Completer<void> _allClosed = Completer<void>();

  /// Open connections, keyed by identity, with the index and pair time each
  /// was given.
  final Map<Connection, ({int index, int openedAt})> _open = {};

  int _opened = 0;
  int _bytesClientToDevice = 0;
  int _bytesDeviceToClient = 0;
  Timer? _progress;
  bool _completed = false;

  /// Connections paired so far.
  int get connections => _opened;

  /// Connections paired but not yet reported closed.
  int get openConnections => _open.length;

  static int _now() => DateTime.timestamp().millisecondsSinceEpoch;

  static Map<String, Object>? _peer(Side side) {
    if (side.remoteHost == 'n/a' || side.remotePort < 0) return null;
    return {'ip': side.remoteHost, 'port': side.remotePort};
  }

  int _liveClientToDevice() =>
      _bytesClientToDevice +
      _open.keys.fold(0, (sum, c) => sum + c.sideA.rcvd);

  int _liveDeviceToClient() =>
      _bytesDeviceToClient +
      _open.keys.fold(0, (sum, c) => sum + c.sideB.rcvd);

  void _onOpened(Connection c) {
    final at = _now();
    final index = ++_opened;
    _open[c] = (index: index, openedAt: at);
    _progress ??= Timer.periodic(progressInterval, (_) => _sendProgress());
    final client = _peer(c.sideA);
    final device = _peer(c.sideB);
    toMain.send(
      IIRequest.create('newConnection', {
        'sessionId': sessionId,
        'at': at,
        'index': index,
        if (client != null) 'client': client,
        if (device != null) 'device': device,
        'stats': stats(),
      }),
    );
  }

  void _onClosed(Connection c) {
    final start = _open.remove(c);
    if (start == null) {
      logger.warning(
        'A close was reported for a connection of $sessionId that was never'
        ' reported open',
      );
      return;
    }
    final closedAt = _closedAt(c);
    _bytesClientToDevice += c.sideA.rcvd;
    _bytesDeviceToClient += c.sideB.rcvd;
    toMain.send(
      IIRequest.create('connectionClosed', {
        'sessionId': sessionId,
        'at': closedAt,
        'index': start.index,
        'openedAt': start.openedAt,
        'closedAt': closedAt,
        'bytesClientToDevice': c.sideA.rcvd,
        'bytesDeviceToClient': c.sideB.rcvd,
      }),
    );
    if (_open.isEmpty && !_allClosed.isCompleted) _allClosed.complete();
  }

  /// The later of the two sides' close times, or now when a side carries
  /// none.
  static int _closedAt(Connection c) {
    final a = c.sideA.closedAt;
    final b = c.sideB.closedAt;
    if (a == null || b == null) return _now();
    return (a.isAfter(b) ? a : b).millisecondsSinceEpoch;
  }

  void _sendProgress() {
    toMain.send(
      IIRequest.create('progress', {
        'sessionId': sessionId,
        'at': _now(),
        'openConnections': _open.length,
        'connections': _opened,
        'bytesClientToDevice': _liveClientToDevice(),
        'bytesDeviceToClient': _liveDeviceToClient(),
      }),
    );
  }

  /// Sends `sessionComplete` once every connection's close has been reported,
  /// or [closeFlushTimeout] plus a second after the call, whichever is first,
  /// and stops reporting. Call it after the connector's `done`.
  Future<void> complete() async {
    if (_completed) return;
    _completed = true;
    _progress?.cancel();
    if (_open.isNotEmpty) {
      await Future.any([_closedDone.future, _allClosed.future]).timeout(
        closeFlushTimeout + const Duration(seconds: 1),
        onTimeout: () {},
      );
    }
    await _openedSub.cancel();
    await _closedSub.cancel();
    final unclosed = _open.length;
    if (unclosed > 0) {
      logger.warning(
        '$unclosed connection(s) of session $sessionId were not reported'
        ' closed within ${closeFlushTimeout.inSeconds + 1}s',
      );
    }
    toMain.send(
      IIRequest.create('sessionComplete', {
        'sessionId': sessionId,
        'at': _now(),
        'stats': stats(),
        'connections': _opened,
        'bytesClientToDevice': _liveClientToDevice(),
        'bytesDeviceToClient': _liveDeviceToClient(),
        'connectionsUnclosed': unclosed,
      }),
    );
  }
}
