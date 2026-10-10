import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/enrollment_signature.dart';
import 'package:noports_core/src/common/handle_server_events.dart';
import 'package:noports_core/src/common/public_lookup.dart';
import 'package:noports_core/src/events/noports_event_types.dart';
import 'package:noports_core/src/srvd/build_env.dart';
import 'package:noports_core/src/srvd/isolates/port_pair_isolate.dart';
import 'package:noports_core/src/srvd/isolates/shared_single_port_isolate.dart';
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/srvd/srvd_util_mixin.dart';
import 'package:socket_connector/socket_connector.dart';

import 'isolates/types.dart';
import 'srvd_session_params.dart';

@protected
class SrvdImpl
    with AtClientBindings, AtEventLogger, SrvdUtilMixin
    implements Srvd {
  @override
  final AtSignLogger logger = AtSignLogger(' srvd main ');
  @override
  AtClient atClient;
  @override
  final Atsign atSign;
  @override
  final String homeDirectory;
  @override
  final String atKeysFilePath;
  @override
  final String managerAtsign;
  @override
  final String ipAddress;
  @override
  final bool logTraffic;
  @override
  final bool bind443;
  @override
  final int localBindPort443;

  /// Window (ms) the auto-detecting relay auth verifiers wait for a connecting
  /// side to speak (legacy) before assuming ESCR and issuing a challenge.
  final int relayAuthDetectWindowMs;

  /// How often to re-check that the signing keys each live session's ESCR
  /// sockets were accepted with haven't been withdrawn; [Duration.zero] turns
  /// the check off.
  final Duration signingKeyCheckInterval;

  /// How this relay looks up the `_apsk` records sockets sign with.
  final PublicLookup publicLookup;

  Timer? _signingKeyCheckTimer;
  final Set<String> _keysBeingChecked = {};

  @override
  bool verbose = false;

  @override
  @visibleForTesting
  bool initialized = false;

  Map<String, SessionInfo> sessions = {};

  final Set<String> _startingSessions = {};

  Isolate? isolate443;
  SendPort? toIsolate443;
  PortPair portPair443 = (443, 443);

  final List<StreamSubscription> _subscriptions = [];

  /// The relay isolates still running: where to send them requests, and when
  /// they exit.
  final Map<Isolate, ({Future<SendPort> toWorker, Future<void> exited})>
  _workers = {};

  bool _stopped = false;

  static const _workerStopTimeout = Duration(seconds: 5);

  @visibleForTesting
  int get runningWorkers => _workers.length;

  SrvdImpl({
    required this.atClient,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.logTraffic,
    required this.verbose,
    required this.bind443,
    required this.localBindPort443,
    required this.relayAuthDetectWindowMs,
    required this.signingKeyCheckInterval,
    PublicLookup? publicLookup,
  }) : publicLookup = publicLookup ?? DirectPublicLookup(atClient) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<Srvd> fromCommandLineArgs(
    List<String> args, {
    AtClient? atClient,
    FutureOr<AtClient> Function(SrvdParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
  }) async {
    try {
      SrvdParams p;
      try {
        p = await SrvdParams.fromArgs(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      if (!await File(p.atKeysFilePath).exists()) {
        throw ArgumentError('Unable to find .atKeys file: ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }
      if (p.debug) {
        AtSignLogger.root_level = 'FINEST';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      var srvd = SrvdImpl(
        atClient: atClient,
        atSign: p.atSign.toAtsign(),
        homeDirectory: p.homeDirectory,
        atKeysFilePath: p.atKeysFilePath,
        managerAtsign: p.managerAtsign,
        ipAddress: p.ipAddress,
        logTraffic: p.logTraffic,
        verbose: p.verbose,
        bind443: p.bind443,
        localBindPort443: p.localBindPort443,
        relayAuthDetectWindowMs: p.relayAuthDetectWindowMs,
        signingKeyCheckInterval: Duration(seconds: p.signingKeyCheckSecs),
      );

      if (p.verbose) {
        srvd.logger.logger.level = Level.INFO;
      }
      return srvd;
    } on ArgumentError catch (e, s) {
      usageCallback?.call(e, s);
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    if (bind443) {
      final r = await spawnNewSinglePortIsolate(
        ipAddress,
        false,
        localBindPort443,
      );
      portPair443 = r.$1;
      isolate443 = r.$2;
      toIsolate443 = r.$3;
    }

    initialized = true;
  }

  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }
    NotificationService notificationService = atClient.notificationService;

    _subscriptions.add(handlePublicKeyChangedEvent(atClient, atSign));

    const String subscriptionRegex = '\\.${Srvd.namespace}@';

    _subscriptions.add(
      notificationService
          .subscribe(regex: subscriptionRegex, shouldDecrypt: true)
          .listen(notificationHandler),
    );

    if (signingKeyCheckInterval > Duration.zero) {
      _signingKeyCheckTimer = Timer.periodic(
        signingKeyCheckInterval,
        (_) => unawaited(checkSigningKeys()),
      );
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _signingKeyCheckTimer?.cancel();
    publicLookup.close();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await Future.wait([
      for (final MapEntry(key: worker, value: (:toWorker, :exited))
          in _workers.entries.toList())
        _stopWorker(worker, toWorker, exited),
    ]);
    sessions.clear();
  }

  /// Tracks [worker] until [exitPort] reports it has exited, then closes
  /// [fromWorker]. A worker registered after [stop] is stopped at once.
  void _register(
    Isolate worker,
    ReceivePort fromWorker,
    ReceivePort exitPort,
    Future<SendPort> toWorker,
  ) {
    final exited = exitPort.first.then((_) {
      exitPort.close();
      fromWorker.close();
    });
    _workers[worker] = (toWorker: toWorker, exited: exited);
    if (_stopped) {
      unawaited(_stopWorker(worker, toWorker, exited));
    }
  }

  /// Asks [worker] to stop, so that it closes its own sockets, and kills it
  /// only if it hasn't exited within [_workerStopTimeout].
  Future<void> _stopWorker(
    Isolate worker,
    Future<SendPort> toWorker,
    Future<void> exited,
  ) async {
    try {
      await Future.any([
        exited,
        toWorker.then((port) {
          port.send(IIRequest.create('stop', null));
          return exited;
        }),
      ]).timeout(_workerStopTimeout);
    } on TimeoutException {
      logger.warning(
        'A relay isolate did not stop within ${_workerStopTimeout.inSeconds}s,'
        ' so it was killed; its sockets may stay open',
      );
      worker.kill(priority: Isolate.immediate);
    }
  }

  Future<void> notificationHandler(AtNotification n) async {
    logger.info('Received notification: ${n.key} from ${n.from} to ${n.to}');
    try {
      if (!wellFormedRequest(n)) {
        logger.shout('Un-handled notification key: ${n.key}');
        return;
      }

      logger.shout('Notification key: ${n.key}');
      String topic;
      String messageType;
      try {
        final topicParts = n.key
            .replaceAll('${n.to}:', '')
            .replaceAll('.${Srvd.namespace}${n.from}', '')
            .toLowerCase()
            .split('.');
        messageType = topicParts.removeLast();
        topic = topicParts.join('.');
      } catch (e) {
        logger.warning('malformed notification key ${n.key}');
        return;
      }

      logger.info(
        '$messageType received from ${n.from}:'
        ' ${n.value}',
      );
      switch (messageType) {
        case 'request_ports':
          return await handleRequestPorts(n);
        case 'auth_modes':
          return await handleAuthModes(n);
        case 'sessions':
          return await handleSessionMessages(topic, n);
        case 'discover_request':
          logger.info('Received discover request from ${n.from}');
          return await handleDiscover(n);
        default:
          logger.warning(
            'unknown "$messageType" request received from ${n.from}'
            ' ( ${n.value} )',
          );
      }
    } catch (e, st) {
      logger.shout(
        'Exception $e while handling notification $n\nStack Trace:\n$st',
      );
    }
  }

  Future<void> handleSessionMessages(String topic, AtNotification n) async {
    final parts = topic.split('.');
    if (parts.length != 2) {
      logger.warning('Invalid sessions sub-topic $topic');
      return;
    }
    String sessionsMessageType = parts[0];
    String sessionId = parts[1];

    if (sessions[sessionId] == null) {
      logger.info('This relay does not know about session $sessionId');
      return;
    }

    final SessionInfo sessionInfo = sessions[sessionId]!;

    // Is the atSign who sent this message one of the participants in the session?
    if (n.from != sessionInfo.atSignA && n.from != sessionInfo.atSignB) {
      logger.shout('Received ${n.from} is not a participant in $sessionId');
      return;
    }

    switch (sessionsMessageType) {
      case 'logging':
        if (sessionInfo.eventLoggingConfig != null) {
          logger.warning(
            'We already have session logging config for $sessionId',
          );
          return;
        }
        final elc = AtEventConfig.fromJson(jsonDecode(n.value!));
        if (!await validAtsign(elc.atSign)) {
          logger.warning('Invalid eventLoggingAtsign ${elc.atSign}');
          return;
        }
        sessionInfo.eventLoggingConfig = elc;

        // The first connection will usually already have happened before
        // the relay receives the eventLoggingConfig, in which case we need
        // to now send the "connected" event
        if (sessionInfo.stats != null) {
          await logEvent(
            sessionInfo.eventLoggingConfig!,
            SessionEvent.connected(
              sessionId: sessionId,
              stats: sessionInfo.stats!,
            ),
          );
        }

        break;
      default:
        logger.warning(
          'unknown "$sessionsMessageType" sessions received from ${n.from}'
          ' ( ${n.value} )',
        );
    }
  }

  Future<bool> validAtsign(String? atSign) async {
    if (atSign == null || !(atSign.startsWith('@'))) {
      return false;
    }
    try {
      final addr = await atClient
          .getRemoteSecondary()
          ?.atLookUp
          .secondaryAddressFinder
          .findSecondary(atSign);
      return addr != null;
    } catch (e) {
      logger.warning('$e while looking up address for atSign $atSign');
      return false;
    }
  }

  Future<void> handleRequestPorts(AtNotification n) async {
    SrvdSessionParams sessionParams;
    try {
      sessionParams = srvdSessionParamsFromJson(n.value!);

      if (n.from.toAtsign() != sessionParams.atSignA.toAtsign()) {
        logger.shout(
          'Session ${sessionParams.sessionId}'
          ' for ${sessionParams.atSignA}'
          ' requested by ${n.from} is denied',
        );
        return;
      }
      if (managerAtsign != 'open' && managerAtsign != sessionParams.atSignA) {
        logger.shout(
          'Session ${sessionParams.sessionId}'
          ' for ${sessionParams.atSignA}'
          ' is denied',
        );
        return;
      }
      if (sessions.containsKey(sessionParams.sessionId) ||
          _startingSessions.contains(sessionParams.sessionId)) {
        logger.shout(
          'Session ${sessionParams.sessionId} requested by ${n.from}'
          ' is denied: a session with that id is already live',
        );
        return;
      }
    } catch (e) {
      logger.shout('Unable to provide the socket pair due to: $e');
      return;
    }

    if (sessionParams.only443) {
      final refusal = SinglePortWorker.whyRefused(sessionParams);
      if (refusal != null) {
        logger.shout(
          'Session ${sessionParams.sessionId} requested by ${n.from}'
          ' is denied: $refusal',
        );
        if (sessionParams.multipleAcksOk) {
          try {
            await sendNack(
              sessionId: sessionParams.sessionId,
              requestingAtsign: n.from,
              message: refusal,
            );
          } catch (e) {
            logger.shout('Error while sending NACK: $e');
          }
        }
        return;
      }
    }

    _startingSessions.add(sessionParams.sessionId);
    try {
      final SrvdSessionParams withKeys;
      try {
        withKeys = await withPayloadKeys(sessionParams);
      } catch (e) {
        logger.shout('Unable to provide the socket pair due to: $e');
        return;
      }
      await _startSession(n, withKeys);
    } finally {
      _startingSessions.remove(sessionParams.sessionId);
    }
  }

  /// Allocates ports for [sessionParams], which [n] requested, records the
  /// session and sends the requester its ports.
  Future<void> _startSession(
    AtNotification n,
    SrvdSessionParams sessionParams,
  ) async {
    logger.info('New session request params: $sessionParams');

    PortPair ports;
    // ignore: unused_local_variable
    Isolate? ppiSpawned;
    SendPort? ppiSendToSpawned;

    try {
      if (sessionParams.only443) {
        ports = (443, 443);
      } else {
        (ports, ppiSpawned, ppiSendToSpawned) = await spawnNewPortPairIsolate(
          sessionParams,
        );
      }
    } catch (e) {
      logger.shout('_spawnSocketConnector exception: $e');
      return;
    }

    if (sessionParams.multipleAcksOk) {
      // client can handle multiple acks, no need to lock a mutex
      logger.shout(
        '😎 Will handle request from ${n.from}'
        ' which can handle multiple acks (no mutex required)',
      );
    } else {
      // client cannot handle multiple acks, so we need to lock a mutex
      var mutexKey =
          AtKey.fromString(
              '${sessionParams.sessionId}'
              '.session_mutexes.${Srvd.namespace}'
              '${atClient.getCurrentAtSign()!}',
            )
            ..metadata = (Metadata()
              ..immutable =
                  true // only one srvd will succeed in doing this
              ..ttl = 30000); // expire after 30 seconds to keep datastore clean
      PutRequestOptions pro = PutRequestOptions()
        ..shouldEncrypt = false
        ..useRemoteAtServer = true;

      try {
        await atClient.put(mutexKey, 'lock', putRequestOptions: pro);
        logger.shout(
          '😎 Will handle request from ${n.from}'
          '; acquired mutex $mutexKey',
        );
      } catch (err) {
        if (err.toString().toLowerCase().contains('immutable')) {
          logger.shout(
            '🤷‍♂️ Will not handle request from ${n.from}'
            '; did not acquire mutex $mutexKey',
          );
          ppiSendToSpawned?.send(IIRequest.create('stop', null));
        } else {
          logger.shout(
            'Will not handle; did not acquire mutex $mutexKey : $err',
          );
        }
        return;
      }
    }

    if (sessionParams.only443 && !bind443) {
      var message =
          'Client requested port 443'
          ' but this relay is not bound to port 443';
      logger.shout(message);
      if (sessionParams.multipleAcksOk) {
        try {
          await sendNack(
            sessionId: sessionParams.sessionId,
            requestingAtsign: n.from,
            message: message,
          );
        } catch (e) {
          logger.shout('Error while sending NACK: $e');
        }
      }
      return;
    }

    sessions[sessionParams.sessionId] = SessionInfo(
      params: sessionParams,
      connector: null,
      toWorker: ppiSendToSpawned,
    );
    if (sessionParams.only443) {
      toIsolate443!.send(IIRequest.create('start', sessionParams));
    }

    var (portA, portB) = ports;
    logger.shout(
      'Started session ${sessionParams.sessionId}'
      ' for ${sessionParams.atSignA} to ${sessionParams.atSignB}'
      ' using ports $ports',
    );

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = sessionParams.sessionId
      ..sharedBy = atSign
      ..sharedWith = n.from
      ..namespace = Srvd.namespace
      ..metadata = metaData;

    String responseVal = createResponseValue(
      ipAddress,
      portA,
      portB,
      sessionParams,
    );

    logger.shout(
      'Sending response data'
      ' for requested session ${sessionParams.sessionId} :'
      ' [$responseVal]',
    );

    try {
      await atClient.notificationService.notify(
        NotificationParams.forUpdate(
          atKey,
          value: responseVal,
          notificationExpiry: Duration(minutes: 1),
        ),
        waitForFinalDeliveryStatus: false,
        checkForFinalDeliveryStatus: false,
      );
    } catch (e) {
      logger.shout("Error sending response to client");
    }

    final fetched = preFetched[sessionParams.sessionId] = {};
    await Future.wait([
      for (final s in sessionParams.preFetch)
        () async {
          try {
            fetched[s] = await _lookupPublic(s);
          } catch (e) {
            logger.shout('$e while preFetching $s');
          }
        }(),
    ]);
    unawaited(
      Future.delayed(
        Duration(seconds: 30),
      ).whenComplete(() => preFetched.remove(sessionParams.sessionId)),
    );
  }

  /// A requesting client, having learnt (via the daemon ping) which relay-auth
  /// mode each side of its session will use, sends this so the relay can skip
  /// the auto-detect window (see [Srvd] / RelayAuthVerifierAuto). Best-effort:
  /// if it arrives after a socket has already connected, that socket falls back
  /// to auto-detect. Only the session's requester (side A) may send it.
  ///
  /// Several relay instances share this atSign and all receive this
  /// notification, but only one is actually handling the session — the one
  /// whose response the client accepted. We match on that response's [rvdNonce]
  /// (unique per relay instance's response) so the others ignore it. (When the
  /// client cannot handle multiple acks, only the mutex-winning relay records
  /// the session at all, so this is a belt-and-braces check there.)
  Future<void> handleAuthModes(AtNotification n) async {
    if (n.value == null) {
      logger.warning('Received auth_modes with empty value from ${n.from}');
      return;
    }
    final Map decoded;
    try {
      decoded = jsonDecode(n.value!);
    } catch (e) {
      logger.warning('Malformed auth_modes request from ${n.from}: $e');
      return;
    }

    final String? sessionId = decoded['sessionId'];
    if (sessionId == null) {
      logger.warning('auth_modes request from ${n.from} has no sessionId');
      return;
    }

    final SessionInfo? si = sessions[sessionId];
    if (si == null) {
      logger.info('auth_modes: this relay does not know session $sessionId');
      return;
    }
    if (n.from != si.params.atSignA) {
      logger.shout(
        'auth_modes: ${n.from} is not the requester (${si.params.atSignA})'
        ' of session $sessionId',
      );
      return;
    }
    if (decoded['rvdNonce'] != si.params.rvdNonce) {
      logger.info(
        'auth_modes: rvdNonce (${decoded['rvdNonce']}) is not this relay\'s'
        ' rvdNonce (${si.params.rvdNonce}) for $sessionId'
        ' — another instance is handling it; ignoring',
      );
      return;
    }

    final SendPort? toWorker = si.toWorker;
    if (toWorker == null) {
      logger.info(
        'auth_modes: no worker isolate for session $sessionId'
        ' (only443 sessions do not auto-detect)',
      );
      return;
    }

    toWorker.send(
      IIRequest.create('auth_modes', {
        'sideA': decoded['sideA'],
        'sideB': decoded['sideB'],
      }),
    );
    logger.info(
      'Forwarded definitive auth modes for $sessionId to worker:'
      ' sideA=${decoded['sideA']} sideB=${decoded['sideB']}',
    );
  }

  Future<void> handleDiscover(AtNotification n) async {
    final metadata = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..namespaceAware = true;

    if (n.value == null) {
      logger.info('Received discover request with an empty value. Ignoring.');
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(n.value!);
    } catch (_) {
      decoded = null;
    }
    if (decoded is! Map || decoded['items'] is! List) {
      logger.warning('Malformed discover request from ${n.from}. Ignoring.');
      return;
    }

    final requestedItems = decoded['items'] as List;
    final response = <String, dynamic>{};
    for (final item in requestedItems) {
      switch (item) {
        case 'ipaddr':
          response['ipaddr'] = ipAddress;
        case 'port':
          response['port'] = bind443 ? 443 : null;
      }
    }

    final atKey = AtKey()
      ..key = 'discover_response'
      ..sharedBy = atSign
      ..sharedWith = n.from
      ..namespace = Srvd.namespace
      ..metadata = metadata;

    final notificationParams = NotificationParams.forUpdate(
      atKey,
      value: jsonEncode(response),
      notificationExpiry: Duration(minutes: 1),
    );

    await atClient.notificationService.notify(
      notificationParams,
      waitForFinalDeliveryStatus: false,
      checkForFinalDeliveryStatus: false,
    );
  }

  Map<String, Map<String, dynamic>> preFetched = {};

  /// The value of the public record [key], whether or not it is written with
  /// its `public:` prefix. Throws when it can't be found.
  Future<String> _lookupPublic(String key) async {
    final uri = key.startsWith('public:') ? key : 'public:$key';
    logger.info('Looking up $uri');
    return await publicLookup.lookup(uri) ??
        (throw AtKeyNotFoundException('$uri does not exist'));
  }

  @override
  Future<void> lookup(IIRequest msg, SendPort toSpawned) async {
    try {
      logger.info('request: "lookup" : ${msg.payload}');
      String sessionId = msg.payload['sessionId'];
      String key = msg.payload['key'];
      String value;
      String fromPreFetch = '';
      if (preFetched[sessionId]?[key] != null) {
        value = preFetched[sessionId]![key];
        fromPreFetch = ' (pre-fetched)';
      } else {
        value = await _lookupPublic(key);
      }
      logger.info('request: "lookup" : success$fromPreFetch: $value');
      toSpawned.send(
        IIResponse(id: msg.id, isError: false, payload: value),
      );
    } catch (err) {
      logger.info('request: "lookup" : error $err');
      toSpawned.send(
        IIResponse(id: msg.id, isError: true, payload: err.toString()),
      );
    }
  }

  Future<void> _handleSessionComplete(IIRequest msg) async {
    final sessionId = msg.payload['sessionId'];
    logger.info('_handleSessionComplete $sessionId');
    SessionInfo? si = sessions[sessionId];
    logger.info(
      'sessionInfo:'
      ' $si eventLoggingConfig: ${si?.eventLoggingConfig}',
    );
    if (si != null && si.eventLoggingConfig != null) {
      await logEvent(
        si.eventLoggingConfig!,
        SessionEvent.done(
          sessionId: sessionId,
          stats: msg.payload['stats'] as Stats,
        ),
      );
    }
    sessions.remove(sessionId);
  }

  /// Forgets a session the single-port isolate refused to start, which would
  /// otherwise stay recorded with nothing left to remove it.
  void _handleStartRefused(IIRequest msg) {
    final String sessionId = msg.payload['sessionId'];
    logger.warning(
      'Single-port isolate refused to start session $sessionId:'
      ' ${msg.payload['reason']}',
    );
    sessions.remove(sessionId);
  }

  /// The most distinct signing keys recorded for one session. Each side of a
  /// session signs with one enrollment's key.
  static const maxSigningKeysPerSession = 4;

  /// Records that a socket of session [sessionId] was accepted with a
  /// signature from the `_apsk` record [signingKeyUri], in the canonical form
  /// an atServer stores it under, so spellings of one record count once.
  @visibleForTesting
  void recordSigningKey(String sessionId, String signingKeyUri) {
    final si = sessions[sessionId];
    if (si == null) return;
    final key = canonicalSigningKeyUri(signingKeyUri);
    if (si.signingKeys.contains(key)) return;
    if (si.signingKeys.length >= maxSigningKeysPerSession) {
      logger.warning(
        'Not recording signing key $key for session $sessionId, which already'
        ' has ${si.signingKeys.length}',
      );
      return;
    }
    si.signingKeys.add(key);
  }

  /// Looks up afresh, each from its own atServer, every `_apsk` record a live
  /// session's ESCR sockets were accepted with, and ends each session one of
  /// them has been withdrawn from: moved by its atServer to `r.__e` (the
  /// enrollment was revoked or superseded) or `d.__e` (deleted or expired). A
  /// key that is merely missing, and a lookup that fails any other way, keep
  /// the session, so an atServer that is unreachable or being restored ends
  /// nothing. A key whose last re-check hasn't finished is left out, so a
  /// slow atServer delays only the re-checks of its own keys.
  @visibleForTesting
  Future<void> checkSigningKeys() async {
    final keys = {
      for (final si in sessions.values)
        if (!si.ending) ...si.signingKeys,
    }.difference(_keysBeingChecked);
    await Future.wait([for (final key in keys) _recheck(key)]);
  }

  Future<void> _recheck(String key) async {
    _keysBeingChecked.add(key);
    try {
      final withdrawnTo = await _whereWithdrawn(key);
      if (withdrawnTo == null) return;
      for (final MapEntry(key: sessionId, value: si)
          in sessions.entries.toList()) {
        if (!si.ending && si.signingKeys.contains(key)) {
          _endSession(sessionId, si, key, withdrawnTo);
        }
      }
    } finally {
      _keysBeingChecked.remove(key);
    }
  }

  /// Where [key] has been withdrawn to, or null when it is still published,
  /// merely missing, or a lookup fails, all of which keep its sessions.
  Future<String?> _whereWithdrawn(String key) async {
    try {
      if (await publicLookup.lookupDirect(key) != null) return null;
    } catch (e) {
      logger.warning(
        'Could not re-check signing key $key, so the sessions it signed'
        ' carry on: $e',
      );
      return null;
    }
    try {
      final withdrawnTo = await publicLookup.withdrawnTo(key);
      if (withdrawnTo == null) {
        logger.warning(
          'Signing key $key is missing but has not been withdrawn, so the'
          ' sessions it signed carry on',
        );
      }
      return withdrawnTo;
    } catch (e) {
      logger.warning(
        'Could not tell whether signing key $key was withdrawn, so the'
        ' sessions it signed carry on: $e',
      );
      return null;
    }
  }

  void _endSession(
    String sessionId,
    SessionInfo si,
    String signingKey,
    String withdrawnTo,
  ) {
    si.ending = true;
    logger.warning(
      'Ending session $sessionId (${si.atSignA} to ${si.atSignB}):'
      ' signing key $signingKey has been withdrawn to $withdrawnTo',
    );
    if (si.toWorker != null) {
      si.toWorker!.send(IIRequest.create('stop', null));
    } else if (si.params.only443) {
      toIsolate443?.send(IIRequest.create('endSession', sessionId));
    }
  }

  Future<void> _handleNewConnection(IIRequest msg) async {
    final sessionId = msg.payload['sessionId'];
    logger.info('_handleNewConnection $sessionId');
    SessionInfo? si = sessions[sessionId];
    if (si == null) {
      return;
    }
    // If we've already got stats then this isn't the first connection, and we
    // only really care about the first connection in order to send the
    // "connected" event.
    if (si.stats != null) {
      return;
    }
    si.stats = msg.payload['stats'];

    // If we already have received an eventLoggingConfig then let's send the
    // "connected" event. If the eventLoggingConfig arrives later than the
    // first connection, then the "connected" event is sent at that time.
    if (si.eventLoggingConfig != null) {
      await logEvent(
        si.eventLoggingConfig!,
        SessionEvent.connected(sessionId: sessionId, stats: si.stats!),
      );
    }
  }

  /// This function spawns a new socketConnector in a background isolate
  /// once the socketConnector has spawned and is ready to accept connections
  /// it sends back the port numbers to the main isolate
  /// then the port numbers are returned from this function
  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  ) async {
    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort fromSpawned = ReceivePort(sessionParams.sessionId);

    PortPairIsolateParams parameters = (
      fromSpawned.sendPort, // spawned will use this to communicate with main
      BuildEnv.enableSnoop && logTraffic,
      verbose,
      sessionParams.sessionId,
      relayAuthDetectWindowMs,
    );

    logger.info(
      "Spawning socket connector isolate"
      " with parameters $parameters",
    );

    /// This function is meant to be run in a separate isolate
    /// It starts the socket connector, and sends back the assigned ports to the main isolate
    /// It then waits for socket connector to die before shutting itself down
    void portPairIsolateEntryPoint(
      PortPairIsolateParams connectorParams,
    ) async {
      PortPairWorker worker = PortPairWorker(
        toMain: connectorParams.$1,
        logTraffic: connectorParams.$2,
        verbose: connectorParams.$3,
        loggingTag: connectorParams.$4,
        relayAuthDetectWindowMs: connectorParams.$5,
      );

      await worker.run();
    }

    final exitPort = ReceivePort();
    Isolate spawned = await Isolate.spawn<PortPairIsolateParams>(
      portPairIsolateEntryPoint,
      parameters,
      onExit: exitPort.sendPort,
    );
    final toWorker = Completer<SendPort>();
    _register(spawned, fromSpawned, exitPort, toWorker.future);

    Completer receivedSendToSpawned = Completer();
    late SendPort toSpawned;
    Completer receivedPortPair = Completer();
    // NOTE the worker can exit with nothing awaiting this, so its error must
    // not surface as uncaught.
    receivedPortPair.future.ignore();
    late PortPair ports;

    logger.info('Waiting for isolate to send its port pair info');
    fromSpawned.listen((msg) async {
      if (msg is SendPort) {
        toSpawned = msg;
        toWorker.complete(msg);
        receivedSendToSpawned.complete();
        return;
      }
      if (msg is PortPair) {
        ports = msg;
        receivedPortPair.complete();
        return;
      }
      if (msg is IIRequest) {
        switch (msg.type) {
          case 'lookup':
            await lookup(msg, toSpawned);
            break;
          case 'signingKey':
            recordSigningKey(msg.payload['sessionId'], msg.payload['key']);
            break;
          case 'newConnection':
            await _handleNewConnection(msg);
            break;
          case 'sessionComplete':
            await _handleSessionComplete(msg);
            break;
          default:
            toSpawned.send(
              IIResponse(
                id: msg.id,
                isError: true,
                payload: 'Unknown request type ${msg.type}',
              ),
            );
            break;
        }
        return;
      }

      if (msg is IIResponse) {
        // find the corresponding request
      }

      logger.shout(
        'Unknown message from isolate -'
        ' type: ${msg.runtimeType} message: $msg',
      );
    }, onDone: () {
      _workers.remove(spawned);
      if (!receivedPortPair.isCompleted) {
        receivedPortPair.completeError(
          StateError('relay isolate exited before reporting its ports'),
        );
      }
    });

    // Wait to receive the SendPort from the spawned isolate
    try {
      await receivedSendToSpawned.future.timeout(
        Duration(milliseconds: isolateStartTimeoutMs),
      );
    } on TimeoutException catch (_) {
      throw TimeoutException(
        'No sendPort received after ${isolateStartTimeoutMs}ms',
      );
    }

    // Ask the spawned isolate to start the session
    toSpawned.send(IIRequest.create('start', sessionParams));

    // Wait to receive the PortPair from the spawned isolate
    try {
      await receivedPortPair.future.timeout(
        Duration(milliseconds: isolateBindPortsTimeoutMs),
      );
    } on TimeoutException catch (_) {
      throw TimeoutException(
        'No sendPort received after ${isolateBindPortsTimeoutMs}ms',
      );
    }

    logger.shout(
      'Received ports $ports in main isolate'
      ' for session ${sessionParams.sessionId}',
    );

    if (_stopped) {
      throw StateError('srvd stopped while starting ${sessionParams.sessionId}');
    }
    return (ports, spawned, toSpawned);
  }

  /// Spawns an isolate which:
  /// - Binds to the required port
  /// - Waits for requests about new sessions from the main isolate
  ///   - --> sessionID, sideA atSign, sideB atSign
  /// - Makes SocketConnector objects for new sessions
  /// - Assigns sockets to SocketConnectors once they have completed auth
  /// (Part of the socket auth job now is to determine the session ID and the atSign)
  @override
  Future<(PortPair, Isolate, SendPort)> spawnNewSinglePortIsolate(
    String address,
    bool useTLS,
    int bindPort,
  ) async {
    /// Spawn the isolate and wait for it to send back the issued port numbers
    ReceivePort fromSpawned = ReceivePort('port $bindPort');

    SinglePortIsolateParams parameters = (
      fromSpawned.sendPort, // spawned will use this to communicate with main
      BuildEnv.enableSnoop && logTraffic, // logTraffic
      verbose, // verbose logging
      '$address:$bindPort', // logging tag
      address,
      useTLS,
      bindPort,
    );

    /// This function is meant to be run in a separate isolate
    /// It starts the socket connector, and sends back the assigned ports to the main isolate
    /// It then waits for socket connector to die before shutting itself down
    void singlePortIsolateEntryPoint(SinglePortIsolateParams params) async {
      SinglePortWorker worker = SinglePortWorker(
        toMain: params.$1,
        logTraffic: params.$2,
        verbose: params.$3,
        loggingTag: params.$4,
        address: params.$5,
        useTLS: params.$6,
        bindPort: params.$7,
      );

      await worker.run();
    }

    logger.info("Spawning single-port isolate for port $bindPort");

    // Spawn the isolate
    final exitPort = ReceivePort();
    Isolate spawned = await Isolate.spawn<SinglePortIsolateParams>(
      singlePortIsolateEntryPoint,
      parameters,
      onExit: exitPort.sendPort,
    );
    final toWorker = Completer<SendPort>();
    _register(spawned, fromSpawned, exitPort, toWorker.future);

    Completer receivedSendToSpawned = Completer();
    late SendPort toSpawned;

    logger.info('Listening for messages from spawned isolate');
    fromSpawned.listen((msg) async {
      if (msg is SendPort) {
        toSpawned = msg;
        toWorker.complete(msg);
        receivedSendToSpawned.complete();
        return;
      }
      if (msg is IIRequest) {
        switch (msg.type) {
          case 'lookup':
            await lookup(msg, toSpawned);
            break;
          case 'signingKey':
            recordSigningKey(msg.payload['sessionId'], msg.payload['key']);
            break;
          case 'newConnection':
            await _handleNewConnection(msg);
            break;
          case 'sessionComplete':
            await _handleSessionComplete(msg);
            break;
          case 'startRefused':
            _handleStartRefused(msg);
            break;
          case 'handleIsolateFailure':
            logger.shout('');
            logger.shout('Single-port isolate failed: ${msg.payload}');
            logger.shout('');
            toSpawned.send(IIRequest.create('stop', false));
            await Future.delayed(Duration(milliseconds: 5));
            logger.shout('');
            logger.shout('Exiting');
            exit(1);
          default:
            toSpawned.send(
              IIResponse(
                id: msg.id,
                isError: true,
                payload: 'Unknown request type ${msg.type}',
              ),
            );
            break;
        }
        return;
      }

      logger.shout(
        'Unknown message from isolate -'
        ' type: ${msg.runtimeType} message: $msg',
      );
    }, onDone: () => _workers.remove(spawned));

    // Wait to receive the SendPort from the spawned isolate
    try {
      logger.info('Waiting for isolate to send its port pair info');
      await receivedSendToSpawned.future.timeout(
        Duration(milliseconds: isolateStartTimeoutMs),
      );
    } on TimeoutException catch (_) {
      throw TimeoutException(
        'No sendPort received after ${isolateStartTimeoutMs}ms',
      );
    }

    if (_stopped) {
      throw StateError('srvd stopped while starting the 443 listener');
    }
    return (portPair443, spawned, toSpawned);
  }

  Future<void> sendNack({
    required String sessionId,
    required String requestingAtsign,
    required String message,
  }) async {
    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = 'nack.$sessionId'
      ..sharedBy = atSign
      ..sharedWith = requestingAtsign
      ..namespace = Srvd.namespace
      ..metadata = metaData;

    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        atKey,
        value: message,
        notificationExpiry: Duration(minutes: 1),
      ),
      waitForFinalDeliveryStatus: false,
      checkForFinalDeliveryStatus: false,
    );
  }
}
