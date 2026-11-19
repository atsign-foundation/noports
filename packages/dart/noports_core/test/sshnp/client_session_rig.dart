import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/npt.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/src/common/session_crypto.dart' show rsaSignString;
import 'package:noports_core/src/sshnp/util/sshnpd_channel/daemon_ping_record.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

const String clientAtSign = '@alice';
const String daemonAtSign = '@bob';
const String relayAtSign = '@relay';
const String deviceName = 'dev';

/// The key of the client's own record of [daemon]'s [device].
String pingRecordKeyOf({
  String daemon = daemonAtSign,
  String device = deviceName,
}) => 'cached.ping.${daemon.substring(1)}.$device.sshnp$clientAtSign';

const String daemonSigningKeyUri = 'public:_apsk.daemon.a.__e$daemonAtSign';

final RsaKeyPair _daemonKeyPair = RsaKeyPair.generate();
final RsaKeyPair _clientKeyPair = RsaKeyPair.generate();
final RsaKeyPair _apkamKeyPair = RsaKeyPair.generate();

/// A ping response from a daemon that does everything npt and sshnp require,
/// and ESCR when [escr]; with no `supportedFeatures` when [features] is false.
Map<String, dynamic> pingResponse({
  required bool escr,
  String? signingKeyUri = daemonSigningKeyUri,
  bool features = true,
}) => {
  'devicename': deviceName,
  if (features)
    'supportedFeatures': {
      DaemonFeature.srAuth.name: true,
      DaemonFeature.srE2ee.name: true,
      DaemonFeature.acceptsPublicKeys.name: false,
      DaemonFeature.supportsPortChoice.name: true,
      DaemonFeature.adjustableTimeout.name: true,
      DaemonFeature.controlChannelHeartbeats.name: true,
      DaemonFeature.supportsRamEscr.name: escr,
      DaemonFeature.twinKeys.name: false,
    },
  if (signingKeyUri != null) 'publicSigningKeyUri': signingKeyUri,
};

/// The value of a ping record stored [age] ago saying [escr] and
/// [signingKeyUri].
String pingRecord({
  required bool escr,
  Duration age = const Duration(days: 1),
  String? signingKeyUri = daemonSigningKeyUri,
}) => DaemonPingRecord(
  storedAt: DateTime.now().subtract(age),
  support: DaemonRelayAuthSupport(
    supportsRamEscr: escr,
    publicSigningKeyUri: signingKeyUri,
  ),
).encode();

/// A record write the client made.
typedef RecordWrite = ({
  String key,
  String value,
  int? ttl,
  bool? useRemoteAtServer,
});

/// The client's own atServer, the daemon and the relay, played by the test,
/// with everything the client sent and wrote recorded in order.
class ClientWorld {
  ClientWorld() {
    atClient = _FakeAtClient(this);
  }

  late final AtClient atClient;
  final _FakeNotifications _notifications = _FakeNotifications();

  /// The client's own records, by key, as values.
  final Map<String, String> records = {};

  /// Thrown by every read of a ping record, when set.
  Object? readFailure;

  /// Thrown by every write of a ping record, when set.
  Object? writeFailure;

  /// Whether reads of a ping record never answer.
  bool readHangs = false;

  /// Whether writes of a ping record never answer.
  bool writeHangs = false;

  /// What every write of a ping record answers.
  bool writeAnswer = true;

  /// Every ping record write, oldest first.
  final List<RecordWrite> writes = [];

  /// Every ping record read: the key and whether it went to the atServer.
  final List<({String key, bool? useRemoteAtServer})> reads = [];

  /// What happened, in order: `sent <key>` for each notification the client
  /// sent, and `delivered <what>` for each the test delivered.
  final List<String> log = [];

  /// Every notification the client sent, oldest first.
  final List<NotificationParams> sent = [];

  final List<void Function()> _onChange = [];
  final Map<(String, String), int> _pingsAnswered = {};
  final Set<String> _relayAnswered = {};

  void _changed() {
    for (final check in List.of(_onChange)) {
      check();
    }
  }

  void _sent(NotificationParams params) {
    sent.add(params);
    log.add('sent ${params.atKey.key}');
    _changed();
  }

  /// What [probe] finds, once something the client sends or reads makes it
  /// find something, or null after five seconds.
  Future<T?> _until<T extends Object>(T? Function() probe) {
    final T? now = probe();
    if (now != null) return Future.value(now);
    final completer = Completer<T?>();
    void check() {
      final T? found = probe();
      if (found != null && !completer.isCompleted) {
        _onChange.remove(check);
        completer.complete(found);
      }
    }

    _onChange.add(check);
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _onChange.remove(check);
        return null;
      },
    );
  }

  /// The pings [client] has sent its daemon device, as any client would.
  List<NotificationParams> _pingsBy(ClientDriver client) => [
    for (final p in sent)
      if (p.atKey.key == 'ping.${client.device}' &&
          p.atKey.sharedWith == client.daemon.toAtsign())
        p,
  ];

  /// Every notification sent whose key holds [part].
  List<NotificationParams> sentTo(String part) => [
    for (final p in sent)
      if (p.atKey.key.contains(part)) p,
  ];

  /// The first notification [client] sent whose key holds [part], or null
  /// when it has sent none within five seconds.
  Future<NotificationParams?> _sentBy(ClientDriver client, String part) =>
      _until(
        () => sentTo(
          part,
        ).where((p) => p.value!.contains(client.sessionId)).firstOrNull,
      );

  Future<Map<String, dynamic>> _valueSentBy(
    ClientDriver client,
    String part,
  ) async {
    final NotificationParams sent =
        await _sentBy(client, part) ??
        (throw TestFailure('${client.name} sent no $part within five seconds'));
    return jsonDecode(sent.value!);
  }

  /// The request_ports [client] sent.
  Future<Map<String, dynamic>> relayRequest(ClientDriver client) =>
      _valueSentBy(client, 'request_ports');

  /// The payload of the session request [client] sent the daemon.
  Future<Map<String, dynamic>> daemonRequest(ClientDriver client) async =>
      (await _valueSentBy(client, client.daemonRequestKey))['payload'];

  /// The auth_modes notification [client] sent the relay, or null when it
  /// sent none.
  Map<String, dynamic>? authModesSentBy(ClientDriver client) => switch (sentTo(
    'auth_modes',
  ).where((p) => p.value!.contains(client.sessionId)).firstOrNull) {
    null => null,
    final p => jsonDecode(p.value!),
  };

  /// Completes once [client] has read its daemon device's ping record and
  /// has had time to act on what it read.
  Future<void> recordReadAndSettled(ClientDriver client) async {
    final String key = pingRecordKeyOf(
      daemon: client.daemon,
      device: client.device,
    );
    await _until(() => reads.any((r) => r.key == key) ? true : null) ??
        (throw TestFailure('${client.name} did not read $key'));
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _deliver(String what, AtNotification notification) {
    log.add('delivered $what');
    _notifications.deliver(notification);
  }

  /// Delivers a notification from [from] under [key], holding [value].
  void deliverAs(String key, {required String from, required String value}) =>
      _deliver(
        key,
        AtNotification(
          'as-${log.length}',
          key,
          from,
          clientAtSign,
          DateTime.now().millisecondsSinceEpoch,
          'update',
          false,
          value: value,
        ),
      );

  /// How many of the client's subscriptions a notification under [key] would
  /// reach.
  int subscriptionsReached(String key) => _notifications.reached(key);

  /// Once [client] has sent a ping this has not answered, its daemon answers
  /// it with [response].
  Future<void> answerPing(
    ClientDriver client,
    Map<String, dynamic> response,
  ) async {
    final String daemon = client.daemon.toAtsign();
    final (String, String) device = (daemon, client.device);
    final int answered = _pingsAnswered[device] ?? 0;
    await _until(() => _pingsBy(client).length > answered ? true : null) ??
        (throw TestFailure('${client.name} sent no ping within five seconds'));
    _pingsAnswered[device] = answered + 1;
    _deliver(
      'ping response',
      AtNotification(
        'ping-${log.length}',
        '$clientAtSign:heartbeat.${client.device}.sshnp$daemon',
        daemon,
        clientAtSign,
        DateTime.now().millisecondsSinceEpoch,
        'update',
        false,
        value: jsonEncode(response),
      ),
    );
  }

  /// Once [client] has asked for ports, the relay answers with [portA] for
  /// the client's socket; the response says so when it [applied] the
  /// request's relayAuthModes and when it [autoDetects].
  Future<void> answerRelay(
    ClientDriver client, {
    bool applied = true,
    bool autoDetects = true,
    int portA = 1,
  }) async {
    await relayRequest(client);
    _relayAnswered.add(client.sessionId);
    _deliver(
      'relay response',
      AtNotification(
        'relay-${log.length}',
        '$clientAtSign:${client.sessionId}.${Srvd.namespace}$relayAtSign',
        relayAtSign,
        clientAtSign,
        DateTime.now().millisecondsSinceEpoch,
        'update',
        false,
        value: jsonEncode({
          'address': '127.0.0.1',
          'portA': portA,
          'portB': 2,
          'rvdNonce': 'relay nonce',
          'supportsEventLogging': false,
          if (autoDetects) 'autoDetectsRelayAuth': true,
          if (applied) 'appliedRelayAuthModes': true,
        }),
      ),
    );
  }

  AtNotification _fromDaemon(ClientDriver client, String value) =>
      AtNotification(
        'daemon-${log.length}',
        '$clientAtSign:${client.sessionId}.${client.device}.sshnp'
            '${client.daemon}',
        client.daemon,
        clientAtSign,
        DateTime.now().millisecondsSinceEpoch,
        'update',
        false,
        value: value,
      );

  /// Once [client] has sent its session request, the daemon refuses it.
  Future<void> refuseSession(ClientDriver client) async {
    await daemonRequest(client);
    _deliver('daemon refusal', _fromDaemon(client, 'refused'));
  }

  /// Once [client] has sent its session request, the daemon accepts it, in a
  /// response signed with its key.
  Future<void> acceptSession(ClientDriver client) async {
    await daemonRequest(client);
    final payload = {'sessionId': client.sessionId};
    _deliver(
      'daemon acceptance',
      _fromDaemon(
        client,
        jsonEncode({
          'payload': payload,
          'signature': rsaSignString(
            jsonEncode(payload),
            privateKey: _daemonKeyPair.atPrivateKey.privateKey,
          ),
          'hashingAlgo': 'sha256',
          'signingAlgo': 'rsa2048',
        }),
      ),
    );
  }

  /// Answers whatever [client] is still waiting for, as a daemon that
  /// supports ESCR and a relay that applied the request's modes, until the
  /// daemon refuses the session or the client gives up first; returns what
  /// [outcome] threw.
  Future<Object?> finish(ClientDriver client, Future<Object?> outcome) async {
    final settled = Completer<Object?>();
    unawaited(outcome.then(settled.complete));
    final int answered = _pingsAnswered[(client.daemon, client.device)] ?? 0;
    if (answered == 0 || _pingsBy(client).length > answered) {
      await answerPing(client, pingResponse(escr: true));
    }
    if (!_relayAnswered.contains(client.sessionId)) await answerRelay(client);
    await Future.any([
      _sentBy(client, client.daemonRequestKey),
      settled.future,
    ]);
    if (!settled.isCompleted) await refuseSession(client);
    return settled.future.timeout(const Duration(seconds: 20));
  }
}

class _FakeNotifications implements NotificationService {
  final Map<String, StreamController<AtNotification>> _subscriptions = {};
  late final ClientWorld world;

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) => _subscriptions
      .putIfAbsent(regex!, () => StreamController.broadcast())
      .stream;

  int reached(String key) =>
      _subscriptions.keys.where((regex) => RegExp(regex).hasMatch(key)).length;

  void deliver(AtNotification notification) {
    _subscriptions.forEach((regex, controller) {
      if (RegExp(regex).hasMatch(notification.key)) {
        controller.add(notification);
      }
    });
  }

  @override
  Future<NotificationResult> notify(
    NotificationParams notificationParams, {
    bool waitForFinalDeliveryStatus = true,
    bool checkForFinalDeliveryStatus = true,
    bool encryptValue = true,
    Function(NotificationResult)? onSuccess,
    Function(NotificationResult)? onError,
    Function(NotificationResult)? onSentToSecondary,
  }) async {
    world._sent(notificationParams);
    return NotificationResult()
      ..notificationID = 'n'
      ..notificationStatusEnum = NotificationStatusEnum.delivered;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not available');
}

class _FakeAtClient implements AtClient {
  _FakeAtClient(this.world) {
    world._notifications.world = world;
  }

  final ClientWorld world;
  AtClientPreference _preference = AtClientPreference();

  @override
  AtClientPreference? getPreferences() => _preference;

  @override
  void setPreferences(AtClientPreference preference) =>
      _preference = preference;

  @override
  String? getCurrentAtSign() => clientAtSign;

  @override
  String? get enrollmentId => null;

  @override
  bool get isStopped => false;

  @override
  late final AtKeysIo atKeysIo = InMemoryAtKeysIo.holding(
    clientAtSign,
    AtKeys.legacy(
      encryptionPublicKey: _clientKeyPair.atPublicKey.publicKey,
      encryptionPrivateKey: _clientKeyPair.atPrivateKey.privateKey,
      apkamPublicKey: _apkamKeyPair.atPublicKey.publicKey,
      apkamPrivateKey: _apkamKeyPair.atPrivateKey.privateKey,
    ),
  );

  @override
  NotificationService get notificationService => world._notifications;

  bool _isPingRecord(String key) => key.startsWith('cached.ping.');

  @override
  Future<AtValue> get(
    AtKey key, {
    bool isDedicated = false,
    GetRequestOptions? getRequestOptions,
  }) async {
    final String name = key.toString();
    if (name == 'public:publickey$daemonAtSign') {
      return AtValue()..value = _daemonKeyPair.atPublicKey.publicKey;
    }
    if (!_isPingRecord(name)) throw AtKeyNotFoundException('$name not found');
    if (world.readHangs) {
      world.reads.add((
        key: name,
        useRemoteAtServer: getRequestOptions?.useRemoteAtServer,
      ));
      return Completer<AtValue>().future;
    }
    try {
      if (world.readFailure != null) throw world.readFailure!;
      final String? value = world.records[name];
      if (value == null) throw AtKeyNotFoundException('$name not found');
      return AtValue()..value = value;
    } finally {
      world.reads.add((
        key: name,
        useRemoteAtServer: getRequestOptions?.useRemoteAtServer,
      ));
      Timer.run(world._changed);
    }
  }

  @override
  Future<bool> put(
    AtKey key,
    dynamic value, {
    bool isDedicated = false,
    PutRequestOptions? putRequestOptions,
  }) async {
    final String name = key.toString();
    if (name.startsWith('public:_apsk.')) return true;
    if (!_isPingRecord(name)) throw UnimplementedError('put $name');
    world.writes.add((
      key: name,
      value: value as String,
      ttl: key.metadata.ttl,
      useRemoteAtServer: putRequestOptions?.useRemoteAtServer,
    ));
    if (world.writeHangs) return Completer<bool>().future;
    if (world.writeFailure != null) throw world.writeFailure!;
    if (!world.writeAnswer) return false;
    world.records[name] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not available');
}

/// A client session under test: npt or sshnp.
abstract class ClientDriver {
  String get name;

  String get sessionId;

  /// The daemon Atsign and the device the session is to.
  String get daemon;

  String get device;

  /// The key part of the session request the client sends the daemon.
  String get daemonRequestKey;

  /// Starts the session; completes with what it threw, or null.
  Future<Object?> start();
}

/// How a test makes a client: its relay auth mode when set explicitly, the
/// 443 path, its ping timeout, and the daemon and device it asks for.
typedef ClientFactory =
    ClientDriver Function(
      ClientWorld world, {
      RelayAuthMode? explicitMode,
      bool only443,
      Duration daemonPingTimeout,
      String daemon,
      String device,
      bool authenticateDeviceToRvd,
      bool encryptRvdTraffic,
    });

class _NptDriver implements ClientDriver {
  _NptDriver(this.npt);

  final Npt npt;

  @override
  String get name => 'npt';

  @override
  String get sessionId => npt.sessionId;

  @override
  String get daemon => npt.params.sshnpdAtSign;

  @override
  String get device => npt.params.device;

  @override
  String get daemonRequestKey => 'npt_request';

  @override
  Future<Object?> start() async {
    try {
      final connector = await npt.runInline();
      connector.close();
      return null;
    } catch (e) {
      return e;
    } finally {
      await npt.close();
    }
  }
}

class _SshnpDriver implements ClientDriver {
  _SshnpDriver(this.sshnp);

  final SshnpDartPureImpl sshnp;

  @override
  String get name => 'sshnp';

  @override
  String get sessionId => sshnp.sessionId;

  @override
  String get daemon => sshnp.params.sshnpdAtSign;

  @override
  String get device => sshnp.params.device;

  @override
  String get daemonRequestKey => 'ssh_request';

  @override
  Future<Object?> start() async {
    try {
      await sshnp.run();
      return null;
    } catch (e) {
      return e;
    }
  }
}

ClientDriver _npt(
  ClientWorld world, {
  RelayAuthMode? explicitMode,
  bool only443 = false,
  Duration daemonPingTimeout = DefaultArgs.daemonPingTimeoutDuration,
  String daemon = daemonAtSign,
  String device = deviceName,
  bool authenticateDeviceToRvd = true,
  bool encryptRvdTraffic = true,
}) => _NptDriver(
  Npt.create(
    params: NptParams(
      clientAtSign: clientAtSign,
      sshnpdAtSign: daemon,
      srvdAtSign: relayAtSign,
      remoteHost: 'localhost',
      remotePort: 22,
      device: device,
      inline: true,
      localHost: '127.0.0.1',
      timeout: const Duration(minutes: 1),
      relayAuthMode: explicitMode ?? DefaultArgs.relayAuthMode,
      relayAuthModeExplicit: explicitMode != null,
      only443: only443,
      daemonPingTimeout: daemonPingTimeout,
      authenticateDeviceToRvd: authenticateDeviceToRvd,
      encryptRvdTraffic: encryptRvdTraffic,
    ),
    atClient: world.atClient,
  ),
);

ClientDriver _sshnp(
  ClientWorld world, {
  RelayAuthMode? explicitMode,
  bool only443 = false,
  Duration daemonPingTimeout = DefaultArgs.daemonPingTimeoutDuration,
  String daemon = daemonAtSign,
  String device = deviceName,
  bool authenticateDeviceToRvd = true,
  bool encryptRvdTraffic = true,
}) => _SshnpDriver(
  SshnpDartPureImpl(
    atClient: world.atClient,
    params: SshnpParams(
      clientAtSign: clientAtSign,
      sshnpdAtSign: daemon,
      srvdAtSign: relayAtSign,
      device: device,
      remoteUsername: 'user',
      sendSshPublicKey: false,
      relayAuthMode: explicitMode ?? DefaultArgs.relayAuthMode,
      relayAuthModeExplicit: explicitMode != null,
      only443: only443,
      daemonPingTimeout: daemonPingTimeout,
      authenticateDeviceToRvd: authenticateDeviceToRvd,
      encryptRvdTraffic: encryptRvdTraffic,
    ),
    identityKeyPair: null,
    logStream: null,
  ),
);

/// Both clients, npt (which NoPorts Desktop runs) and sshnp.
const List<ClientFactory> clients = [_npt, _sshnp];

/// A loopback socket standing in for the relay's port for the client, closed
/// after the test; [firstBytes] completes with what the client first sends.
class RelayPortA {
  RelayPortA._(this._server) {
    _server.listen((socket) {
      _sockets.add(socket);
      if (!_connected.isCompleted) _connected.complete();
      socket.listen((bytes) {
        received.write(utf8.decode(bytes));
        if (!_first.isCompleted) _first.complete(utf8.decode(bytes));
      }, onError: (_) {});
    });
  }

  static Future<RelayPortA> open() async {
    final port = RelayPortA._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    addTearDown(port.close);
    return port;
  }

  final ServerSocket _server;
  final List<Socket> _sockets = [];
  final Completer<String> _first = Completer();
  final Completer<void> _connected = Completer();

  /// Everything the client has sent so far.
  final StringBuffer received = StringBuffer();

  int get port => _server.port;

  /// Completes when the client connects, within five seconds.
  Future<void> get connected =>
      _connected.future.timeout(const Duration(seconds: 5));

  /// What the client first sends, or null when it has sent nothing within
  /// five seconds.
  Future<String?> get firstBytes => _first.future
      .then<String?>((s) => s)
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  Future<void> close() async {
    for (final s in _sockets) {
      s.destroy();
    }
    await _server.close();
  }
}
