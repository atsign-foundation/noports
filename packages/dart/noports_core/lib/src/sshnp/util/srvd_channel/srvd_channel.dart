import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/subscription_tracking.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/relay_messages.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/daemon_ping_record.dart';
import 'package:noports_core/srv.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

@visibleForTesting
enum SrvdAck {
  /// srvd acknowledged our request
  acknowledged,

  /// srvd acknowledged our request and had errors
  acknowledgedWithErrors,

  /// srvd did not acknowledge our request
  notAcknowledged,
}

abstract class SrvdChannel<T>
    with
        AsyncInitialization,
        AtClientBindings,
        ApkamSigning,
        SubscriptionTracking {
  @override
  final logger = AtSignLogger(' SrvdChannel ');

  @override
  final AtClient atClient;

  final SrvGenerator<T> srvGenerator;
  final SrvdChannelParams params;
  final String sessionId;
  final String clientNonce = DateTime.now().toIso8601String();

  /// What the daemon is taken to support when the relay is asked for ports,
  /// set before [initialize]. When null the daemon is taken not to support
  /// ESCR, so the request names legacy for side B, except on port 443, where
  /// it names ESCR for both sides.
  DaemonRelayAuthSupport? daemonRelayAuthSupport;

  late RelayAuthModes _requestedRelayAuthModes;

  Completer acked = Completer();

  bool fetched = false;

  late RelayResponse _relayResponse;

  RelayResponse get relayResponse {
    if (fetched) {
      return _relayResponse;
    } else {
      throw SshnpError('Not yet fetched from srvd');
    }
  }

  /// The relay's address (ip address or fqdn)
  String get rvdHost => relayResponse.address;

  /// This is the port which the sshnp **daemon** will connect to
  int get daemonPort => relayResponse.portB;

  /// This is the port which the sshnp **client** will connect to
  int get clientPort => relayResponse.portA;

  String get rvdNonce => relayResponse.rvdNonce;

  bool get supportsEventLogging => relayResponse.supportsEventLogging;

  /// Whether the relay we were assigned authenticates each side by its own
  /// relay-auth mode, taking side B's from [sendDefinitiveAuthModes] when the
  /// request leaves it open. Only such a relay can reconcile a client and
  /// daemon using different modes; older relays apply one session-wide mode to
  /// both sockets.
  bool get autoDetectsRelayAuth => relayResponse.autoDetectsRelayAuth;

  /// The relay-auth mode a side will actually use. This is the
  /// progressive-rollout gate: ESCR is used only where the whole path is known
  /// to handle it, otherwise legacy — which every relay and daemon understands.
  ///
  /// - [only443]: the 443 single-port relay multiplexes both sides on one port
  ///   and is ESCR-only on every relay version (it rejects a legacy payload), so
  ///   the 443 path always uses ESCR regardless of the rest.
  /// - [prescribed]: the caller explicitly chose [preference] (CLI/config/API),
  ///   which overrides the progressive gate, except that a peer that cannot do
  ///   ESCR is given legacy. A relay that applies the request's ESCR to both
  ///   sides refuses that peer's socket at connect; the sessions a relay that
  ///   does not auto-detect can never reconcile are rejected up front by
  ///   [escrRequestedButUnreconcilable].
  /// - [autoDetect]: a relay that does NOT auto-detect applies one session-wide
  ///   mode to both sockets — we declared the universally-safe legacy mode in
  ///   request_ports, so both sides use it (ESCR would break a peer that can't
  ///   do it). A relay that DOES auto-detect lets each side use its own best.
  /// - [preference]/[peerSupportsEscr]: with an auto-detecting relay, a side
  ///   uses ESCR only when the client prefers it and the peer supports it.
  @visibleForTesting
  static RelayAuthMode effectiveRelayAuthMode({
    required RelayAuthMode preference,
    required bool autoDetect,
    required bool peerSupportsEscr,
    required bool only443,
    required bool prescribed,
  }) {
    if (only443) return RelayAuthMode.escr;
    if (prescribed) {
      // Honour the explicit choice, but never ask a peer to speak ESCR it
      // cannot do: degrade THIS side to legacy (the client always supports
      // ESCR, so side A is unaffected). A relay that applies the request's
      // ESCR to both sides refuses such a daemon's socket; a non-auto-detecting
      // relay does so too, and that case is rejected up front (see
      // [escrRequestedButUnreconcilable] / initialize()).
      if (preference == RelayAuthMode.escr && !peerSupportsEscr) {
        return RelayAuthMode.payload;
      }
      return preference;
    }
    if (!autoDetect) return RelayAuthMode.payload;
    return (preference == RelayAuthMode.escr && peerSupportsEscr)
        ? RelayAuthMode.escr
        : RelayAuthMode.payload;
  }

  /// Whether ESCR is unavoidably required of the daemon this session but the
  /// daemon cannot do it — in which case the session must be rejected up front
  /// rather than fail mid-connect.
  ///
  /// Never true unless the daemon both authenticates to the relay
  /// ([authenticateDeviceToRvd]) and cannot do ESCR ([daemonSupportsEscr]
  /// false) — otherwise there is nothing to reconcile. Given that, ESCR is
  /// unavoidable on the daemon's socket when EITHER:
  /// - [only443] — the 443 single-port path is ESCR-only end-to-end on every
  ///   relay (a legacy socket has no side field), so a non-ESCR daemon can never
  ///   use it; or
  /// - the user explicitly chose ESCR ([explicitEscr]) AND the relay does NOT
  ///   auto-detect ([autoDetect] false) — an older relay applies one mode to
  ///   both sockets and ignores the definitive-auth-modes hint, so the daemon
  ///   cannot legacy-degrade independently.
  ///
  /// In every other explicit-ESCR case the client uses ESCR on its own side and
  /// tells a daemon that cannot do ESCR to use legacy; a relay that applies the
  /// request's ESCR to both sides refuses that daemon's socket at connect.
  static bool escrRequestedButUnreconcilable({
    required bool explicitEscr,
    required bool only443,
    required bool authenticateDeviceToRvd,
    required bool autoDetect,
    required bool daemonSupportsEscr,
  }) {
    if (!authenticateDeviceToRvd || daemonSupportsEscr) return false;
    return only443 || (explicitEscr && !autoDetect);
  }

  /// Each side's mode when the daemon [daemonSupportsEscr], at a relay that
  /// [autoDetect]s or applies the request's modes when true.
  RelayAuthModes _modes({
    required bool autoDetect,
    required bool daemonSupportsEscr,
  }) {
    RelayAuthMode mode(bool peerSupportsEscr) => effectiveRelayAuthMode(
          preference: params.relayAuthMode,
          autoDetect: autoDetect,
          peerSupportsEscr: peerSupportsEscr,
          only443: params.only443,
          prescribed: params.relayAuthModeExplicit,
        );
    return (sideA: mode(true), sideB: mode(daemonSupportsEscr));
  }

  /// Each side's mode at the relay we were assigned: the modes the request
  /// named, when the relay applied them, and otherwise what it can reconcile.
  RelayAuthModes _sessionModes({required bool daemonSupportsEscr}) =>
      relayResponse.appliedRelayAuthModes
          ? _requestedRelayAuthModes
          : _modes(
              autoDetect: autoDetectsRelayAuth,
              daemonSupportsEscr: daemonSupportsEscr,
            );

  /// The relay-auth mode the daemon (side B) should use for this session, told
  /// to it in the session request.
  RelayAuthMode daemonRelayAuthMode({required bool daemonSupportsEscr}) =>
      _sessionModes(daemonSupportsEscr: daemonSupportsEscr).sideB;

  /// Throws [SshnpError] when the daemon's [live] ping answer means this
  /// attempt must end before the daemon is asked for anything.
  ///
  /// That is only when the relay applied the request's modes, and the side B
  /// mode [live] gives is legacy where the request named ESCR or, under an
  /// explicit relay-auth mode, differs at all from what the request named.
  void checkDaemonAnswer(DaemonRelayAuthSupport? live) {
    if (live == null || !relayResponse.appliedRelayAuthModes) return;
    final RelayAuthModes now = _modes(
      autoDetect: true,
      daemonSupportsEscr: live.supportsRamEscr,
    );
    final bool ends = params.relayAuthModeExplicit
        ? now != _requestedRelayAuthModes
        : _requestedRelayAuthModes.sideB == RelayAuthMode.escr &&
            now.sideB == RelayAuthMode.payload;
    if (ends) {
      throw SshnpError(
        "The daemon's relay auth support changed since it was last seen"
        ' (device ${params.device} of ${params.sshnpdAtSign}); try again',
      );
    }
  }

  // * Volatile fields set at runtime

  String? aesKeyC2D;
  String? ivC2D;
  String? aesKeyD2C;
  String? ivD2C;
  String? _relayAuthAesKey;

  String? get relayAuthAesKey {
    switch (params.relayAuthMode) {
      case RelayAuthMode.payload:
        return null;
      case RelayAuthMode.escr:
        _relayAuthAesKey ??= generateAes256Key();
        return _relayAuthAesKey;
    }
  }

  /// Whether srvd acknowledged our request
  @visibleForTesting
  SrvdAck srvdAck = SrvdAck.notAcknowledged;

  /// Will be set when we receive a NACK notification from srvd
  String srvdNackMessage = '';

  SrvdChannel({
    required this.atClient,
    required this.params,
    required this.sessionId,
    required this.srvGenerator,
  }) {
    logger.level = params.verbose ? 'info' : 'shout';
  }

  @override
  Future<void> initialize() async {
    Future publishPSKFuture = publishPublicSigningKey();
    // NOTE: awaited only after the relay answers - see the same guard on the
    // feature check in Npt.initialize. The await below still sees the error.
    publishPSKFuture.ignore();

    await getHostAndPortFromSrvd();

    await publishPSKFuture;

    completeInitialization();
  }

  Future<T?> runSrv({
    int? localRvPort,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  }) async {
    await callInitialization();

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    late Srv<T> srv;

    RelayAuthenticator? relayAuthenticator;
    if (params.authenticateClientToRvd) {
      switch (_sessionModes(daemonSupportsEscr: true).sideA) {
        case RelayAuthMode.payload:
          relayAuthenticator = RelayAuthenticatorLegacy(
            await signAndWrapAndJsonEncode(atClient, {
              'sessionId': sessionId,
              'clientNonce': clientNonce,
              'rvdNonce': rvdNonce,
            }),
          );
          break;
        case RelayAuthMode.escr:
          final signingKeyPair = await escrSigningKeyPair(this);
          relayAuthenticator = RelayAuthenticatorESCR(
            sessionId: sessionId,
            relayAuthAesKey: relayAuthAesKey!,
            publicSigningKeyUri: publicSigningKeyUri,
            publicSigningKey: signingKeyPair.publicKey,
            privateSigningKey: signingKeyPair.privateKey,
            signingAlgo: signingKeyPair.algorithm,
            isSideA: true,
          );
          break;
      }
    }
    // Get the local host to bind to
    String? localHost;
    if (params is NptParams && (params as NptParams).localHost != null) {
      final nptParams = params as NptParams;
      localHost = nptParams.localHost;
      logger.info('Will bind to: $localHost');
    }

    srv = srvGenerator(
      rvdHost,
      clientPort,
      localPort: localRvPort,
      bindLocalPort: true,
      localHost: localHost,
      relayAuthenticator: relayAuthenticator,
      aesC2D: aesC2D,
      ivC2D: ivC2D,
      aesD2C: aesD2C,
      ivD2C: ivD2C,
      multi: multi,
      detached: detached,
      timeout: timeout,
      controlChannelHeartbeat: controlChannelHeartbeat,
    );
    return srv.run();
  }

  /// Tell the relay definitively which relay-auth mode each side of this session
  /// will use. A relay whose request left side B's mode open waits for this
  /// before it challenges the daemon's socket, unless that socket sends a
  /// legacy envelope first.
  ///
  /// Only sent when the relay auto-detects and did not apply the request's
  /// `relayAuthModes`; an older relay applies one session-wide mode and does
  /// not handle this notification.
  /// Side A is this client; side B is the daemon, which uses ESCR only if it
  /// supports it ([daemonSupportsEscr], learnt from the daemon ping).
  /// Fire-and-forget: sent before the daemon session request so it usually
  /// reaches the relay before the daemon's socket does, though a relay that
  /// waits for it does not need it to. A send failure is logged and swallowed;
  /// a relay that waits for it then never challenges a daemon using ESCR, and
  /// the session fails.
  ///
  /// Several relay instances can share the relay atSign; we selected one (whose
  /// response we accepted) and include its unique [rvdNonce] so the others,
  /// which also receive this notification, ignore it.
  Future<void> sendDefinitiveAuthModes({required bool daemonSupportsEscr}) async {
    if (!autoDetectsRelayAuth || relayResponse.appliedRelayAuthModes) return;

    final RelayAuthModes modes =
        _sessionModes(daemonSupportsEscr: daemonSupportsEscr);

    final AtKey authModesKey = AtKey()
      ..key = '${params.device}.auth_modes.${Srvd.namespace}'
      ..sharedBy = params.clientAtSign
      ..sharedWith = params.srvdAtSign
      ..metadata = (Metadata()
        ..namespaceAware = false
        ..ttl = 10000);

    final String value = jsonEncode({
      'sessionId': sessionId,
      'rvdNonce': rvdNonce,
      'sideA': modes.sideA.name,
      'sideB': modes.sideB.name,
    });

    logger.info('Sending definitive auth modes to srvd: $value');
    try {
      await notify(
        authModesKey,
        value,
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
        ttln: Duration(minutes: 1),
      );
    } catch (e) {
      logger.warning('Failed to send definitive auth modes to srvd: $e');
    }
  }

  @protected
  @visibleForTesting
  Future<void> getHostAndPortFromSrvd({
    Duration timeout = DefaultArgs.relayResponseTimeoutDuration,
  }) async {
    srvdAck = SrvdAck.notAcknowledged;
    _requestedRelayAuthModes = _modes(
      autoDetect: true,
      daemonSupportsEscr: daemonRelayAuthSupport?.supportsRamEscr ?? false,
    );
    track(
      subscribe(
        regex: '$sessionId.${Srvd.namespace}@',
        shouldDecrypt: true,
      ).listen((notification) async {
        if (notification.from.toAtsign() != params.srvdAtSign.toAtsign()) {
          logger.warning(
            'Ignoring a response for session $sessionId'
            ' from ${notification.from}, which is not ${params.srvdAtSign}',
          );
          return;
        }
        if (acked.isCompleted) {
          logger.warning(
            'Got additional relay response ${notification.value} - ignoring',
          );
          return;
        }

        if (notification.key.contains('nack.$sessionId')) {
          logger.warning('Got NACK response from relay: ${notification.key}');
          srvdNackMessage = notification.value.toString();

          srvdAck = SrvdAck.acknowledgedWithErrors;
          acked.complete();

          return;
        }

        String notifVal = notification.value.toString();
        logger.info('Received from srvd: $notifVal');
        if (notifVal.startsWith('{')) {
          _relayResponse = RelayResponse.fromJson(jsonDecode(notifVal));
        } else {
          // legacy response format
          List results = notifVal.split(',');
          _relayResponse = RelayResponse(
            address: results[0],
            portA: int.parse(results[1]),
            portB: int.parse(results[2]),
            rvdNonce: results[3],
            supportsEventLogging: false,
          );
        }

        srvdAck = SrvdAck.acknowledged;
        fetched = true;
        acked.complete();

        logger.info(
          'Received from srvd:'
          ' rvdHost:clientPort:daemonPort $rvdHost:$clientPort:$daemonPort'
          ' rvdNonce: $rvdNonce',
        );
        logger.info('Daemon will connect to: $rvdHost:$daemonPort');
      }),
    );
    logger.info('Started listening for srvd response');

    late AtKey rvdRequestKey;
    late String rvdRequestValue;

    rvdRequestKey = AtKey()
      ..key = '${params.device}.request_ports.${Srvd.namespace}'
      ..sharedBy = params
          .clientAtSign // shared by us
      ..sharedWith = params
          .srvdAtSign // shared with the srvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the srvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttl = 10000);

    List<String> preFetch = [];

    // Currently prefetch is only needed if auth mode is ESCR
    if (params.relayAuthMode == RelayAuthMode.escr) {
      preFetch.add(publicSigningKeyUri);
      final String? daemonKeyUri = daemonRelayAuthSupport?.publicSigningKeyUri;
      if (daemonKeyUri != null) {
        preFetch.add(daemonKeyUri);
      }
    }

    var message = RelayRequest(
      sessionId: sessionId,
      atSignA: params.clientAtSign,
      atSignB: params.sshnpdAtSign,
      authenticateSocketA: params.authenticateClientToRvd,
      authenticateSocketB: params.authenticateDeviceToRvd,
      clientNonce: clientNonce,
      // NOTE: a relay that ignores relayAuthModes reads this instead
      relayAuthMode: effectiveRelayAuthMode(
        preference: params.relayAuthMode,
        autoDetect: false,
        peerSupportsEscr: true,
        only443: params.only443,
        prescribed: params.relayAuthModeExplicit,
      ),
      relayAuthModes: _requestedRelayAuthModes,
      relayAuthAesKey: relayAuthAesKey,
      only443: params.only443,
      multipleAcksOk: true,
      preFetch: preFetch,
      sendJsonResponse: true,
    );

    rvdRequestValue = jsonEncode(message.toJson());

    logger.info('Sending notification to srvd with key $rvdRequestKey');
    await notify(
      rvdRequestKey,
      rvdRequestValue,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    logger.info(
      'Will wait for a response for up to ${timeout.inSeconds} seconds',
    );
    try {
      await acked.future.timeout(timeout);
    } on TimeoutException catch (_) {
      logger.warning(
        'Timed out waiting for srvd response after ${timeout.inSeconds} seconds',
      );
      throw TimeoutException(
        'Connection timeout to srvd ${params.srvdAtSign} service',
      );
    }

    if (srvdAck == SrvdAck.acknowledgedWithErrors) {
      throw SshnpError(srvdNackMessage);
    }
  }
}
