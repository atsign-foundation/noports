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
import 'package:noports_core/src/common/handle_server_events.dart';
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

  @override
  bool verbose = false;

  @override
  @visibleForTesting
  bool initialized = false;

  Map<String, SessionInfo> sessions = {};

  Isolate? isolate443;
  SendPort? toIsolate443;
  PortPair portPair443 = (443, 443);

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
  }) {
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
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
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
      );

      if (p.verbose) {
        srvd.logger.logger.level = Level.INFO;
      }
      return srvd;
    } catch (e, s) {
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

    handlePublicKeyChangedEvent(atClient, atSign);

    const String subscriptionRegex = '\\.${Srvd.namespace}@';

    notificationService
        .subscribe(regex: subscriptionRegex, shouldDecrypt: true)
        .listen(notificationHandler);
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
      sessionParams = await srvdSessionParamsFromNotification(n.value!);

      if (managerAtsign != 'open' && managerAtsign != sessionParams.atSignA) {
        logger.shout(
          'Session ${sessionParams.sessionId}'
          ' for ${sessionParams.atSignA}'
          ' is denied',
        );
        return;
      }
    } catch (e) {
      logger.shout('Unable to provide the socket pair due to: $e');
      return;
    }

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

    if (sessionParams.only443) {
      if (!bind443) {
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
      } else {
        toIsolate443!.send(IIRequest.create('start', sessionParams));
      }
    }

    sessions[sessionParams.sessionId] = SessionInfo(
      params: sessionParams,
      connector: null,
      toWorker: ppiSendToSpawned,
    );

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

    preFetched[sessionParams.sessionId] = {};
    for (final s in sessionParams.preFetch) {
      try {
        final AtValue value = await _atClientLookup(AtKey.fromString(s));
        preFetched[sessionParams.sessionId]![s] = value.value;
      } catch (e) {
        logger.shout('$e while preFetching $s');
      }
    }
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

    final decoded = jsonDecode(n.value!);
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

  Future<AtValue> _atClientLookup(AtKey atKey) async {
    logger.info('Looking up $atKey on atServer');
    return await atClient.get(
      atKey,
      getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
    );
  }

  @override
  Future<void> lookup(IIRequest msg, SendPort toSpawned) async {
    try {
      logger.info('request: "lookup" : ${msg.payload}');
      String sessionId = msg.payload['sessionId'];
      String key = msg.payload['key'];
      AtValue value;
      String fromPreFetch = '';
      if (preFetched[sessionId]?[key] != null) {
        value = AtValue()..value = preFetched[sessionId]?[key];
        fromPreFetch = ' (pre-fetched)';
      } else {
        value = await _atClientLookup(AtKey.fromString(key));
      }
      logger.info('request: "lookup" : success$fromPreFetch: ${value.value}');
      toSpawned.send(
        IIResponse(id: msg.id, isError: false, payload: value.value),
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

    Isolate spawned = await Isolate.spawn<PortPairIsolateParams>(
      portPairIsolateEntryPoint,
      parameters,
    );

    Completer receivedSendToSpawned = Completer();
    late SendPort toSpawned;
    Completer receivedPortPair = Completer();
    late PortPair ports;

    logger.info('Waiting for isolate to send its port pair info');
    fromSpawned.listen((msg) async {
      if (msg is SendPort) {
        toSpawned = msg;
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
    Isolate spawned = await Isolate.spawn<SinglePortIsolateParams>(
      singlePortIsolateEntryPoint,
      parameters,
    );

    Completer receivedSendToSpawned = Completer();
    late SendPort toSpawned;

    logger.info('Listening for messages from spawned isolate');
    fromSpawned.listen((msg) async {
      if (msg is SendPort) {
        toSpawned = msg;
        receivedSendToSpawned.complete();
        return;
      }
      if (msg is IIRequest) {
        switch (msg.type) {
          case 'lookup':
            await lookup(msg, toSpawned);
            break;
          case 'newConnection':
            await _handleNewConnection(msg);
            break;
          case 'sessionComplete':
            await _handleSessionComplete(msg);
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
    });

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
