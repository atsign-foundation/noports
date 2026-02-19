import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:at_utils/at_logger.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/src/common/handle_server_events.dart';
import 'package:noports_core/src/events/noports_event_types.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
import 'package:noports_core/src/srv/srv.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/src/version.dart';
import 'package:socket_connector/socket_connector.dart';

@protected
class SshnpdImpl
    with AtClientBindings, ApkamSigning, AtEventLogger
    implements Sshnpd {
  @override
  final AtSignLogger logger = AtSignLogger(' sshnpd ');

  @override
  late AtClient atClient;

  @override
  final String username;

  @override
  final String homeDirectory;

  @override
  final String device;

  @override
  Atsign get deviceAtsign => atClient.getCurrentAtSign()!.toAtsign();

  @override
  final List<String> managerAtsigns;

  @override
  final Atsign? policyManagerAtsign;

  @override
  final SupportedSshClient sshClient;

  @override
  final bool makeDeviceInfoVisible;

  @override
  final bool addSshPublicKeys;

  final String localSshdHost = "localhost";

  @override
  final int localSshdPort;

  @override
  final String sshPublicKeyPermissions;
  final String _sshPublicKeySeparator; // ' ' if there are permissions else ''

  @override
  final String deviceGroup;

  @override
  @visibleForTesting
  bool initialized = false;

  /// The version of whatever program is using this library.
  @override
  final String version;

  @override
  final Future<void> Function(AtNotification)? notifPreProcessor;

  @override
  late final bool inline;

  @override
  late final bool strict;

  AuthChecker? authChecker;

  late final Map<String, dynamic> pingResponse;

  final List<String> permitOpen;

  @override
  AtEventConfig? elc;

  SshnpdImpl({
    // final fields
    required this.atClient,
    required this.username,
    required this.homeDirectory,
    required this.device,
    required this.managerAtsigns,
    this.policyManagerAtsign,
    required this.sshClient,
    this.makeDeviceInfoVisible = false,
    this.addSshPublicKeys = false,
    this.localSshdPort = DefaultSshnpdArgs.localSshdPort,
    this.sshPublicKeyPermissions = DefaultSshnpdArgs.sshPublicKeyPermissions,
    required this.deviceGroup,
    required this.version,
    required this.permitOpen,
    this.authChecker,
    bool? inline,
    this.notifPreProcessor,
    required this.strict,
  }) : _sshPublicKeySeparator = (sshPublicKeyPermissions.isEmpty ? "" : " ") {
    this.inline = inline ?? Platform.environment['SRV_INLINE'] == 'true';
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
    logger.hierarchicalLoggingEnabled = true;

    if (authChecker == null && policyManagerAtsign != null) {
      authChecker = _NPAAuthChecker(this);
    }

    if (addSshPublicKeys) {
      logger.info(
        "Starting sshnpd with addSshPublicKeys on, using permissions: "
        "'$sshPublicKeyPermissions'",
      );
    }

    pingResponse = {
      'devicename': device,
      'deviceGroupName': deviceGroup,
      'version': version,
      'corePackageVersion': packageVersion,
      'supportedFeatures': {
        DaemonFeature.srAuth.name: true,
        DaemonFeature.srE2ee.name: true,
        DaemonFeature.acceptsPublicKeys.name: addSshPublicKeys,
        DaemonFeature.supportsPortChoice.name: true,
        DaemonFeature.adjustableTimeout.name: true,
        DaemonFeature.controlChannelHeartbeats.name: true,
        DaemonFeature.supportsRamEscr.name: true,
        DaemonFeature.twinKeys.name: true,
      },
      'authModes': RelayAuthMode.values.map((c) => c.name).toList(),
      'allowedServices': permitOpen,
      'npCpVersion': DaemonFeature.latestVersion.toString(),
      'publicSigningKeyUri': publicSigningKeyUri,
    };
  }

  static Future<Sshnpd> fromCommandLineArgs(
    List<String> args, {
    AtClient? atClient,
    FutureOr<AtClient> Function(SshnpdParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    void Function()? helpCallback,
    void Function()? versionCallback,
    required String version,
    Future<void> Function(AtNotification)? notifPreProcessor,
  }) async {
    try {
      SshnpdParams p;
      try {
        p = await SshnpdParams.fromArgs(
          args,
          helpCallback: helpCallback,
          versionCallback: versionCallback,
        );
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      // Check atKeyFile selected exists
      if (!await File(p.atKeysFilePath).exists()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SEVERE';
      if (p.debug) {
        AtSignLogger.root_level = 'FINEST';
      } else if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      if (atClient == null && atClientGenerator == null) {
        throw StateError('atClient and atClientGenerator are both null');
      }

      atClient ??= await atClientGenerator!(p);

      var sshnpd = SshnpdImpl(
        atClient: atClient,
        username: p.username,
        homeDirectory: p.homeDirectory,
        device: p.device,
        managerAtsigns: p.managerAtsigns,
        policyManagerAtsign: p.policyManagerAtsign?.toAtsign(),
        sshClient: p.sshClient,
        makeDeviceInfoVisible: p.makeDeviceInfoVisible,
        addSshPublicKeys: p.addSshPublicKeys,
        localSshdPort: p.localSshdPort,
        sshPublicKeyPermissions: p.sshPublicKeyPermissions,
        deviceGroup: p.deviceGroup,
        version: version,
        permitOpen: p.permitOpen.split(',').map((e) => e.trim()).toList(),
        strict: p.strict,
        notifPreProcessor: notifPreProcessor,
      );

      if (p.debug) {
        sshnpd.logger.logger.level = Level.FINEST;
      } else if (p.verbose) {
        sshnpd.logger.logger.level = Level.INFO;
      }

      if (p.clearCachedPKs) {
        sshnpd.logger.shout('Clearing cached public keys');
        sshnpd.logger.shout(
          'Note: locally cached public keys are no longer'
          ' used by sshnpd',
        );
        await clearLocallyCachedPKs(
          logger: sshnpd.logger,
          fs: LocalFileSystem(),
          atClient: sshnpd.atClient,
        );
      }
      return sshnpd;
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

    await publishPublicSigningKey();

    initialized = true;
  }

  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }

    await _shareUsername();

    logger.info('Starting heartbeat');
    startHeartbeats();

    handlePublicKeyChangedEvent(atClient, deviceAtsign);

    String regex = '(^$device|\\.$device)\\.${DefaultArgs.namespace}@';
    logger.info('Subscribing to $regex');
    atClient.notificationService
        .subscribe(regex: regex, shouldDecrypt: true)
        .listen(
          clientRequestNotificationHandler,
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'),
        );

    // Refresh the device entry now, and every hour
    await _refreshDeviceEntry();
    if (makeDeviceInfoVisible) {
      Timer.periodic(
        const Duration(hours: 1),
        (_) async => await _refreshDeviceEntry(),
      );
    }

    await subscribeToPolicyUpdates();

    // If using a policy service, tell it we're here
    await _sendHeartbeatToPolicy();
    Timer.periodic(
      DefaultSshnpdArgs.policyHeartbeatFrequency,
      (_) async => await _sendHeartbeatToPolicy(),
    );

    logger.info('Daemon is running');
  }

  /// 1. Periodically send a 'noop' on the main atLookUp connection, so that
  /// the connection is kept alive in normal conditions.
  /// 2. Listen for notification listener currentState changes and log a
  /// message when it changes
  void startHeartbeats() {
    // 1. keep-alive on the main atLookUp connection
    Timer.periodic(Duration(seconds: 90), (timer) async {
      try {
        await atClient.getRemoteSecondary()?.atLookUp.executeCommand(
          'noop:0\n',
          auth: true,
        );
      } catch (_) {}
    });

    // 2. Log a message when notification listener state changes
    NotificationListenerState? lastState;
    atClient.notificationService.currentListenerStateStream.listen((nls) {
      if (nls != lastState) {
        logger.shout('Notification listener state changed to $nls');
        lastState = nls;
      }
    });
  }

  /// Notification handler for requests from clients
  Future<void> clientRequestNotificationHandler(
    AtNotification notification,
  ) async {
    try {
      try {
        if (notifPreProcessor != null) {
          await notifPreProcessor!(notification);
        }
      } catch (e) {
        logger.shout(
          'Notification pre-processing failed with $e\n'
          'Notification: $notification',
        );
        return;
      }

      String messageType = notification.key
          .replaceAll('${notification.to}:', '')
          .replaceAll(
            '.$device.${DefaultArgs.namespace}${notification.from}',
            '',
          )
          // convert to lower case as the latest AtClient converts notification
          // keys to lower case when received
          .toLowerCase();

      NPAAuthCheckResponse auth = await authCheck(notification);
      if (!auth.authorized) {
        // TODO IF $someConditions apply then send a 'nice' error
        // TODO message notification back to the requester
        logger.shout(
          'Notification ignored from ${notification.from}'
          ' which is not authorized: ${auth.message}'
          ' Notification value was ${notification.value}',
        );

        return;
      }

      // For session-based requests, try to acquire mutex before processing
      if (messageType == 'npt_request' || messageType == 'ssh_request') {
        bool mutexAcquired = await tryAcquireSessionMutex(
          notification,
          messageType,
        );
        if (!mutexAcquired) {
          return; // Another sshnpd instance will handle this request
        }
      }

      switch (messageType) {
        case 'sshpublickey':
          await _handlePublicKeyNotification(notification);
          break;

        case 'ping':
          logger.info(
            '$messageType received from ${notification.from}'
            ' ( ${notification.value} )',
          );
          _handlePingNotification(notification);
          break;

        case 'npt_request':
          logger.info(
            '$messageType received from ${notification.from}'
            ' ( ${notification.value} )',
          );
          _handleNptRequestNotification(notification, auth);
          break;

        case 'ssh_request':
          logger.info(
            '$messageType received from ${notification.from}'
            ' ( ${notification.value} )',
          );
          _handleSshRequestNotification(notification, auth);
          break;

        default:
          logger.warning(
            'unknown "$messageType" request received from ${notification.from}'
            ' ( ${notification.value} )',
          );
      }
    } catch (e, st) {
      logger.shout(
        'Unexpected exception handling client request notification $notification',
      );
      logger.shout('Stack Trace:\n$st');
    }
  }

  Future<void> _logEvent(Map<String, dynamic> event) async {
    if (elc != null) {
      // Log the session requested event
      await logEvent(elc!, event);
    }
  }

  Future<NPAAuthCheckResponse> authCheck(AtNotification notification) async {
    const authTimeoutSeconds = 10;
    String clientAtsign = notification.from;

    if (managerAtsigns.contains(clientAtsign)) {
      return NPAAuthCheckResponse(
        authorized: true,
        message:
            'Approved without policy check;'
            ' client atSign $clientAtsign is a manager of this daemon',
        permitOpen: ['*:*'],
      );
    }

    if (authChecker != null) {
      late NPAAuthCheckResponse resp;
      try {
        logger.info(
          'Asking $policyManagerAtsign'
          ' whether $clientAtsign may connect to this daemon',
        );
        resp = await authChecker!
            .mayConnect(clientAtsign: clientAtsign)
            .timeout(const Duration(seconds: authTimeoutSeconds));
      } on TimeoutException {
        resp = NPAAuthCheckResponse(
          authorized: false,
          message: 'Timed out waiting for authorizer response',
          permitOpen: [],
        );
      }

      return resp;
    }

    return NPAAuthCheckResponse(
      authorized: false,
      message: '$clientAtsign is not in --managers list',
      permitOpen: [],
    );
  }

  /// Attempts to acquire a session-based mutex for load balancing between multiple sshnpd instances.
  /// Returns true if mutex was acquired (this instance should handle the request),
  /// false if another instance already acquired the mutex (this instance should ignore the request).
  @visibleForTesting
  Future<bool> tryAcquireSessionMutex(
    AtNotification notification,
    String notificationKey,
  ) async {
    try {
      // Extract session ID from the notification payload
      String? sessionId = await extractSessionId(notification, notificationKey);
      if (sessionId == null) {
        logger.warning(
          'Could not extract session ID from $notificationKey notification, proceeding without mutex',
        );
        return true; // Proceed without mutex for backward compatibility
      }

      // Create a mutex key using the session ID
      var mutexKey =
          AtKey.fromString(
              '$sessionId'
              '.session_mutexes.${DefaultArgs.namespace}'
              '${atClient.getCurrentAtSign()!}',
            )
            ..metadata = (Metadata()
              ..immutable =
                  true // only one sshnpd will succeed in doing this
              ..ttl = 30000); // expire after 30 seconds to keep datastore clean

      PutRequestOptions pro = PutRequestOptions()
        ..shouldEncrypt = false
        ..useRemoteAtServer = true;

      await atClient.put(mutexKey, 'lock', putRequestOptions: pro);
      logger.info(
        '😎 Will handle $notificationKey request from ${notification.from}'
        '; acquired mutex $mutexKey',
      );
      return true;
    } catch (err) {
      if (err.toString().toLowerCase().contains('immutable')) {
        logger.info(
          '🤷‍♂️ Will not handle $notificationKey request from ${notification.from}'
          '; did not acquire session mutex (another sshnpd instance will handle this)',
        );
        return false;
      } else {
        logger.info('Unexpected error acquiring session mutex: $err');
        return true; // Proceed anyway to maintain functionality
      }
    }
  }

  /// Extracts the session ID from notification payloads for mutex purposes
  @visibleForTesting
  Future<String?> extractSessionId(
    AtNotification notification,
    String notificationKey,
  ) async {
    try {
      if (notificationKey == 'npt_request' ||
          notificationKey == 'ssh_request') {
        // Parse the JSON payload to extract session ID
        final envelope = jsonDecode(notification.value!);
        final Map<String, dynamic> params = envelope['payload'];
        return params['sessionId'] as String?;
      }
      return null;
    } catch (e) {
      logger.warning('Failed to extract session ID from notification: $e');
      return null;
    }
  }

  void _handlePingNotification(AtNotification notification) {
    logger.info(
      'ping received from ${notification.from} notification id : ${notification.id}',
    );

    var atKey = AtKey()
      ..key = 'heartbeat.$device'
      ..sharedBy = deviceAtsign
      ..sharedWith = notification.from
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..ttl =
            10000 // allow only ten seconds before this record expires
        ..namespaceAware = true);

    /// send a heartbeat back
    unawaited(_notify(atKey: atKey, value: jsonEncode(pingResponse)));
  }

  Future<void> _handlePublicKeyNotification(AtNotification notification) async {
    if (!addSshPublicKeys) {
      logger.info(
        'Ignoring sshpublickey from ${notification.from} notification id : ${notification.id}',
      );
      return;
    }

    try {
      final String sshPublicKey;
      logger.info(
        'ssh Public Key received from ${notification.from} notification id : ${notification.id}',
      );
      sshPublicKey = notification.value!;

      // Check to see if the ssh public key is
      // supported keys by the dartssh2 package
      if (!sshPublicKey.startsWith(
        RegExp(
          r'^(ecdsa-sha2-nistp)|(rsa-sha2-)|(ssh-rsa)|(ssh-ed25519)|(ecdsa-sha2-nistp)',
        ),
      )) {
        throw ('$sshPublicKey does not look like a public key');
      }

      // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
      var authKeysFilePath = [
        homeDirectory,
        '.ssh',
        'authorized_keys',
      ].join(Platform.pathSeparator);
      var authKeys = File(authKeysFilePath);

      var authKeysContent = await authKeys.readAsString();

      if (!authKeysContent.contains(sshPublicKey)) {
        authKeys.writeAsStringSync(
          '$sshPublicKeyPermissions$_sshPublicKeySeparator$sshPublicKey',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      logger.severe(
        "Error writing to"
        " $username's .ssh/authorized_keys file : $e",
      );
    }
  }

  String? sessionIdFromNotification(AtNotification notification) {
    try {
      Map envelope = jsonDecode(notification.value!);
      assertValidMapValue(envelope, 'signature', String);
      assertValidMapValue(envelope, 'hashingAlgo', String);
      assertValidMapValue(envelope, 'signingAlgo', String);

      return envelope['payload']?['sessionId'];
    } catch (_) {
      return null;
    }
  }

  /// Handles ssh_request notifications from sshnp clients
  /// by converting them to NptSessionRequest format and routing through
  /// the NPT path with multi: false (single connection mode).
  void _handleSshRequestNotification(
    AtNotification notification,
    NPAAuthCheckResponse auth,
  ) async {
    Atsign requestingAtsign = notification.from.toAtsign();

    late final Map envelope;
    late final NptSessionRequest req;
    try {
      envelope = jsonDecode(notification.value!);
      assertValidMapValue(envelope, 'signature', String);
      assertValidMapValue(envelope, 'hashingAlgo', String);
      assertValidMapValue(envelope, 'signingAlgo', String);

      Map<String, dynamic> payload = envelope['payload'];
      final sshnpReq = SshnpSessionRequest.fromJson(payload);

      // Convert SshnpSessionRequest to NptSessionRequest
      req = NptSessionRequest(
        sessionId: sshnpReq.sessionId,
        rvdHost: sshnpReq.host,
        rvdPort: sshnpReq.port,
        requestedHost: 'localhost',
        requestedPort: localSshdPort,
        authenticateToRvd: sshnpReq.authenticateToRvd ?? false,
        relayAuthMode: sshnpReq.relayAuthMode,
        relayAuthAesKey: sshnpReq.relayAuthAesKey,
        clientNonce: sshnpReq.clientNonce ?? '',
        rvdNonce: sshnpReq.rvdNonce ?? '',
        encryptRvdTraffic: sshnpReq.encryptRvdTraffic ?? false,
        clientEphemeralPK: sshnpReq.clientEphemeralPK ?? '',
        clientEphemeralPKType: sshnpReq.clientEphemeralPKType ?? '',
        timeout: Duration(milliseconds: NptSessionRequest.defaultTimeout),
        twinKeys: sshnpReq.twinKeys,
        relayAtsign: sshnpReq.relayAtsign,
      );

      logger.info(
        'Converted legacy ssh_request to npt_request format'
        ' for session ${req.sessionId}',
      );
    } catch (e) {
      logger.warning(
        'Failed to extract parameters from legacy ssh_request'
        ' notification value "${notification.value}" with error : $e',
      );
      return;
    }

    await _logEvent(
      SessionEvent.requested(
        sessionId: req.sessionId,
        clientAtsign: requestingAtsign,
        daemonAtsign: deviceAtsign,
        device: device,
        policyAtsign: policyManagerAtsign,
        relayAtsign: req.relayAtsign,
        host: req.requestedHost,
        port: req.requestedPort,
      ),
    );

    if (strict) {
      bool verified = await verifyRequestSignature(
        requestingAtsign,
        req.sessionId,
        envelope,
      );
      if (!verified) {
        return;
      }
    }

    String requested = '${req.requestedHost}:${req.requestedPort}';
    if (!_permittedToOpen(permitOpen, req)) {
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Connection to $requested denied based on daemon --permit-open $permitOpen',
        sessionId: req.sessionId,
      );
      return;
    }

    if (!_permittedToOpen(auth.permitOpen, req)) {
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Connection to $requested denied based on POLICY --permit-open ${auth.permitOpen}',
        sessionId: req.sessionId,
      );
      return;
    }

    await _logEvent(
      SessionEvent.approved(
        sessionId: req.sessionId,
        message: 'Connection approved',
        authInfo: auth.toJson(),
      ),
    );

    // Start our side of the tunnel with multi: false (single-connection mode for SSH)
    try {
      await startNpt(
        requestingAtsign: requestingAtsign,
        req: req,
        multi: false,
      );
    } catch (e) {
      logger.severe('startNpt (ssh_request) failed with unexpected error : $e');
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Failed to start up the daemon side of the relay socket tunnel : $e',
        sessionId: req.sessionId,
      );
      return;
    }

    if (req.relayAtsign != null && elc != null) {
      final keyForRelay = AtKey.fromString(
        '${req.relayAtsign}:logging.${req.sessionId}.sessions.${Srvd.namespace}$deviceAtsign',
      )..metadata.namespaceAware = false;
      logger.info('Sending session logging config to relay : $keyForRelay');
      await notify(
        keyForRelay,
        jsonEncode(elc!.toJson()),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
        ttln: Duration(minutes: 1),
      );
    }
  }

  void _handleNptRequestNotification(
    AtNotification notification,
    NPAAuthCheckResponse auth,
  ) async {
    Atsign requestingAtsign = notification.from.toAtsign();

    // Extract the NPT request payload.
    late final Map envelope;
    late final NptSessionRequest req;
    try {
      envelope = jsonDecode(notification.value!);
      assertValidMapValue(envelope, 'signature', String);
      assertValidMapValue(envelope, 'hashingAlgo', String);
      assertValidMapValue(envelope, 'signingAlgo', String);

      Map<String, dynamic> params = envelope['payload'];

      req = NptSessionRequest.fromJson(params);
    } catch (e) {
      logger.warning(
        'Failed to extract parameters from notification value "${notification.value}" with error : $e',
      );
      return;
    }

    await _logEvent(
      SessionEvent.requested(
        sessionId: req.sessionId,
        clientAtsign: requestingAtsign,
        daemonAtsign: deviceAtsign,
        device: device,
        policyAtsign: policyManagerAtsign,
        relayAtsign: req.relayAtsign,
        host: req.requestedHost,
        port: req.requestedPort,
      ),
    );

    if (strict) {
      bool verified = await verifyRequestSignature(
        requestingAtsign,
        req.sessionId,
        envelope,
      );
      if (!verified) {
        return;
      }
    }

    String requested = '${req.requestedHost}:${req.requestedPort}';
    // Check if this *daemon* allows connections to the requested host / port
    if (!_permittedToOpen(permitOpen, req)) {
      await _logEvent(
        SessionEvent.denied(
          sessionId: req.sessionId,
          authInfo: NPAAuthCheckResponse(
            authorized: false,
            message: 'DAEMON denied request',
            permitOpen: permitOpen,
          ).toJson(),
        ),
      );

      // Notify noports client that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Connection to $requested denied based on daemon --permit-open $permitOpen',
        sessionId: req.sessionId,
      );

      return;
    }

    // Check if this *client* is allowed connections to the requested host / port
    if (!_permittedToOpen(auth.permitOpen, req)) {
      await _logEvent(
        SessionEvent.denied(
          sessionId: req.sessionId,
          authInfo: NPAAuthCheckResponse(
            authorized: false,
            message: 'POLICY denied request',
            permitOpen: auth.permitOpen,
          ).toJson(),
        ),
      );

      // Notify noports client that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Connection to $requested denied based on POLICY --permit-open ${auth.permitOpen}',
        sessionId: req.sessionId,
      );

      return;
    }

    await _logEvent(
      SessionEvent.approved(
        sessionId: req.sessionId,
        message: 'Connection approved',
        authInfo: auth.toJson(),
      ),
    );

    // Start our side of the tunnel
    try {
      await startNpt(requestingAtsign: requestingAtsign, req: req, multi: true);
    } catch (e) {
      logger.severe('startNpt failed with unexpected error : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
          requestingAtsign: requestingAtsign,
          sessionId: req.sessionId,
        ),
        value:
            'Failed to start up the daemon side of the relay socket tunnel : $e',
        sessionId: req.sessionId,
      );

      return;
    }

    if (req.relayAtsign != null && elc != null) {
      logger.info(
        'relayAtsign ${req.relayAtsign}'
        ' eventLoggingConfig $elc',
      );
      final keyForRelay = AtKey.fromString(
        '${req.relayAtsign}:logging.${req.sessionId}.sessions.${Srvd.namespace}$deviceAtsign',
      )..metadata.namespaceAware = false;
      logger.info('Sending session logging config to relay : $keyForRelay');
      await notify(
        keyForRelay,
        jsonEncode(elc!.toJson()),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
        ttln: Duration(minutes: 1),
      );
    }
  }

  bool _permittedToOpen(List<String> po, NptSessionRequest req) {
    String requested = '${req.requestedHost}:${req.requestedPort}';
    // Check if this daemon allows connections to the requested host / port
    return (po.contains(requested) ||
        po.contains('*:${req.requestedPort}') ||
        po.contains('${req.requestedHost}:*') ||
        po.contains('*:*'));
  }

  Future<void> startNpt({
    required String requestingAtsign,
    required NptSessionRequest req,
    bool multi = true,
  }) async {
    logger.info(
      'Setting up ports for tunnel session using ${sshClient.name} ($sshClient) from: $requestingAtsign session: ${req.sessionId}',
    );

    RelayAuthenticator? relayAuthenticator;

    if (req.authenticateToRvd) {
      switch (req.relayAuthMode) {
        case RelayAuthMode.payload:
          relayAuthenticator = RelayAuthenticatorLegacy(
            signAndWrapAndJsonEncode(atClient, {
              'sessionId': req.sessionId,
              'clientNonce': req.clientNonce,
              'rvdNonce': req.rvdNonce,
            }),
          );
          break;
        case RelayAuthMode.escr:
          relayAuthenticator = RelayAuthenticatorESCR(
            sessionId: req.sessionId,
            relayAuthAesKey: req.relayAuthAesKey!,
            publicSigningKeyUri: publicSigningKeyUri,
            publicSigningKey: publicSigningKey,
            privateSigningKey: privateSigningKey,
            isSideA: false,
          );
          break;
      }
    }

    AesKeyBundle? c2dBundle, d2cBundle;
    if (req.encryptRvdTraffic) {
      late EncryptionKeyType encKeyType;
      try {
        encKeyType = EncryptionKeyType.values.byName(req.clientEphemeralPKType);
      } catch (e) {
        throw Exception(
          'Unknown ephemeralPKType: ${req.clientEphemeralPKType}',
        );
      }

      c2dBundle = await genBundle(encKeyType, req.clientEphemeralPK);

      if (req.twinKeys) {
        logger.info('Session will use twinned keys');
        d2cBundle = await genBundle(encKeyType, req.clientEphemeralPK);
      }
    }
    if (inline) {
      SocketConnector sc = await Srv.dart(
        req.rvdHost,
        req.rvdPort,
        localPort: req.requestedPort,
        bindLocalPort: false,
        localHost: req.requestedHost,
        relayAuthenticator: relayAuthenticator,
        aesC2D: c2dBundle?.aesKey,
        ivC2D: c2dBundle?.iv,
        aesD2C: d2cBundle?.aesKey,
        ivD2C: d2cBundle?.iv,
        multi: multi,
        timeout: req.timeout,
      ).run();
      logger.info('Started rv INLINE - socket connector $sc');
    } else {
      // Connect to rendezvous point using background process.
      // This program can then exit without causing an issue.
      Process rv = await Srv.exec(
        req.rvdHost,
        req.rvdPort,
        localPort: req.requestedPort,
        bindLocalPort: false,
        localHost: req.requestedHost,
        relayAuthenticator: relayAuthenticator,
        aesC2D: c2dBundle?.aesKey,
        ivC2D: c2dBundle?.iv,
        aesD2C: d2cBundle?.aesKey,
        ivD2C: d2cBundle?.iv,
        multi: multi,
        timeout: req.timeout,
      ).run();
      logger.info('Started rv - pid is ${rv.pid}');
    }

    /// - Send response message to the sshnp client which includes the
    ///   ephemeral private key
    String aesKeyC2DName, ivC2DName;
    if (req.twinKeys) {
      aesKeyC2DName = 'aesKeyC2D';
      ivC2DName = 'ivC2D';
    } else {
      aesKeyC2DName = 'sessionAESKey';
      ivC2DName = 'sessionIV';
    }
    await _notify(
      atKey: _createResponseAtKey(
        requestingAtsign: requestingAtsign,
        sessionId: req.sessionId,
      ),
      value: signAndWrapAndJsonEncode(atClient, {
        'status': 'connected',
        'sessionId': req.sessionId,
        aesKeyC2DName: c2dBundle?.aesKeyEncrypted,
        ivC2DName: c2dBundle?.ivEncrypted,
        'aesKeyD2C': d2cBundle?.aesKeyEncrypted,
        'ivD2C': d2cBundle?.ivEncrypted,
        'eventLoggingConfig': elc?.toJson(),
      }),
      sessionId: req.sessionId,
    );

    await _logEvent(SessionEvent.daemonConnecting(sessionId: req.sessionId));
  }

  AtKey _createResponseAtKey({
    required String requestingAtsign,
    required String sessionId,
  }) {
    var atKey = AtKey()
      ..key = '$sessionId.$device'
      ..sharedBy = deviceAtsign
      ..sharedWith = requestingAtsign
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..ttl = 10000);
    return atKey;
  }

  /// This function sends a notification given an atKey and value
  Future<void> _notify({
    required AtKey atKey,
    required String value,
    bool checkForFinalDeliveryStatus = false,
    bool waitForFinalDeliveryStatus = false,
    Duration ttln = const Duration(minutes: 1),
    String sessionId = '',
  }) async {
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        atKey,
        value: value,
        notificationExpiry: ttln,
      ),
      checkForFinalDeliveryStatus: checkForFinalDeliveryStatus,
      waitForFinalDeliveryStatus: waitForFinalDeliveryStatus,
      onSuccess: (notification) {
        logger.info('SUCCESS:$notification for: $sessionId with value: $value');
      },
      onError: (notification) {
        logger.info('ERROR:$notification');
      },
    );
  }

  /// This function shares or un-shares the username with each of the
  /// [managerAtsigns]
  /// - if [makeDeviceInfoVisible] is true, shares a
  ///   'username.$device.sshnp' record with each managerAtsign
  /// - if [makeDeviceInfoVisible] is false, deletes any
  ///   'username.$device.sshnp' records
  Future<void> _shareUsername() async {
    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttr =
          -1 // we want this to be cacheable by managerAtsign
      ..ccd =
          true // we want cached copies to be deleted if the key is deleted
      ..namespaceAware = true;

    for (final managerAtsign in managerAtsigns) {
      var atKey = AtKey()
        ..key = 'username.$device'
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = DefaultArgs.namespace
        ..metadata = metaData;

      // Only share this information if configured to do so
      if (makeDeviceInfoVisible) {
        try {
          logger.info('Sharing username $username with $managerAtsign');
          await _notify(
            atKey: atKey,
            value: username,
            ttln: Duration(minutes: 1),
            waitForFinalDeliveryStatus: false,
            checkForFinalDeliveryStatus: false,
          );
        } catch (e) {
          stderr.writeln(e.toString());
        }
      } else {
        logger.info('Un-sharing username $username from $managerAtsign');
        try {
          await atClient.delete(
            atKey,
            deleteRequestOptions: DeleteRequestOptions()
              ..useRemoteAtServer = true,
          );
        } catch (e) {
          stderr.writeln(e.toString());
        }
      }
    }
  }

  /// This function shares or un-shares device info with each of the [managerAtsigns]
  /// - if [makeDeviceInfoVisible] is true, shares a
  ///   'device_info.$device.sshnp' record with each managerAtsign
  /// - if [makeDeviceInfoVisible] is false, deletes any
  ///   'device_info.$device.sshnp' records
  Future<void> _refreshDeviceEntry() async {
    const ttl = 1000 * 60 * 60 * 24 * 30; // 30 days
    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttr =
          -1 // we want this to be cacheable by managerAtsign
      ..ccd =
          true // we want cached copies to be deleted if the key is deleted
      ..ttl =
          ttl // but to expire after 30 days
      ..updatedAt = DateTime.now()
      ..namespaceAware = true;

    for (final managerAtsign in managerAtsigns) {
      var atKey = AtKey()
        ..key = 'device_info.$device'
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = DefaultArgs.namespace
        ..metadata = metaData;

      if (makeDeviceInfoVisible) {
        try {
          logger.info('Sharing device info for $device with $managerAtsign');
          await atClient.put(
            atKey,
            jsonEncode(pingResponse),
            putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
          );
        } catch (e) {
          stderr.writeln(e.toString());
        }
      } else {
        logger.info('Un-sharing device info for $device from $managerAtsign');
        try {
          await atClient.delete(
            atKey,
            deleteRequestOptions: DeleteRequestOptions()
              ..useRemoteAtServer = true,
          );
        } catch (e) {
          stderr.writeln(e.toString());
        }
      }
    }
  }

  /// When using a policy service, subscribe to updates from it
  Future<void> subscribeToPolicyUpdates() async {
    if (policyManagerAtsign == null) {
      return;
    }
    String regex =
        '\\.$device\\.devices\\.policy\\.${DefaultArgs.namespace}$policyManagerAtsign';
    logger.shout('Subscribing to $regex');
    subscribe(
      regex: regex,
      shouldDecrypt: true,
    ).listen(policyNotificationHandler);
  }

  void policyNotificationHandler(AtNotification notification) async {
    String messageType = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll(
          '.$device.devices.policy.${DefaultArgs.namespace}$policyManagerAtsign',
          '',
        )
        .toLowerCase();

    logger.info(
      '$messageType received from ${notification.from}:'
      ' ${notification.value}',
    );
    switch (messageType) {
      case 'config':
        await handlePolicyConfigNotification(notification);
        break;
      default:
        logger.warning(
          'unknown "$messageType" message received from ${notification.from}'
          ' ( ${notification.value} )',
        );
    }
  }

  Future<void> handlePolicyConfigNotification(AtNotification n) async {
    logger.shout('Config from policy: ${n.key} : ${n.value}');
    if (n.value == null) {
      return;
    }
    final json = jsonDecode(n.value!);
    final elcJson = json['eventLoggingConfig'];
    if (elcJson == null) {
      logger.shout('No eventLoggingConfig');
      return;
    }
    elc = AtEventConfig.fromJson(elcJson);
  }

  /// If using a policy service, tell it we're here
  Future<void> _sendHeartbeatToPolicy() async {
    if (policyManagerAtsign == null) {
      return;
    }
    var atKey = AtKey()
      ..key = '$device.devices.policy'
      ..sharedBy = deviceAtsign
      ..sharedWith = policyManagerAtsign
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true);

    logger.info('Sending heartbeat to policy service $policyManagerAtsign');

    /// send it
    await _notify(
      atKey: atKey,
      value: jsonEncode(pingResponse),
      ttln: DefaultSshnpdArgs.policyHeartbeatFrequency,
    );
  }

  Future<bool> verifyRequestSignature(
    Atsign requestingAtsign,
    String sessionId,
    Map envelope,
  ) async {
    try {
      await verifyEnvelopeSignature(
        atClient,
        requestingAtsign,
        logger,
        envelope,
      );
    } catch (e) {
      logger.shout('Failed to verify signature of msg from $requestingAtsign');
      logger.shout('Exception: $e');
      logger.shout('Notification value: $envelope');

      try {
        // Notify noports client that this session is NOT connected
        await _notify(
          atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign,
            sessionId: sessionId,
          ),
          value:
              'Signature not verified: Likely that the client atSign\'s'
              ' public key has changed: $e',
          sessionId: sessionId,
        );
      } catch (e) {
        logger.shout('Failed to send nack notification to client: $e');
      }
      return false;
    }
    return true;
  }
}

abstract interface class AuthChecker {
  Future<NPAAuthCheckResponse> mayConnect({required String clientAtsign});
}

class _NPAAuthChecker implements AuthChecker, AtRpcCallbacks {
  final Sshnpd sshnpd;
  late final AtRpc rpc;
  final Map<String, int> authCheckCache = {};
  final Map<int, Completer<NPAAuthCheckResponse>> completerMap = {};

  _NPAAuthChecker(this.sshnpd) {
    rpc = AtRpc(
      atClient: sshnpd.atClient,
      baseNameSpace: DefaultArgs.namespace,
      domainNameSpace: 'auth_checks',
      allowList: {sshnpd.policyManagerAtsign!},
      callbacks: this,
      isClient: true,
      isServer: false,
    );
    rpc.start();
  }

  @override
  Future<NPAAuthCheckResponse> mayConnect({
    required String clientAtsign,
  }) async {
    // We're caching auth checks for 30 seconds so we don't bombard the
    // auth server unnecessarily.
    if (authCheckCache.containsKey(clientAtsign)) {
      return completerMap[authCheckCache[clientAtsign]!]!.future;
    }
    AtRpcReq request = AtRpcReq.create(
      NPAAuthCheckRequest(
        daemonAtsign: sshnpd.deviceAtsign,
        daemonDeviceName: sshnpd.device,
        daemonDeviceGroupName: sshnpd.deviceGroup,
        clientAtsign: clientAtsign,
      ).toJson(),
    );

    completerMap[request.reqId] = Completer<NPAAuthCheckResponse>();
    authCheckCache[clientAtsign] = request.reqId;

    // To keep memory tidy, we'll clear this request and its cached response
    // after 15 seconds
    Future.delayed(Duration(seconds: 15), () {
      completerMap.remove(request.reqId);
      authCheckCache.remove(clientAtsign);
    });

    sshnpd.logger.info(
      'Sending auth check request to sshnpa at ${sshnpd.policyManagerAtsign} : $request',
    );
    await rpc.sendRequest(
      toAtSign: sshnpd.policyManagerAtsign!,
      request: request,
    );
    return completerMap[request.reqId]!.future;
  }

  /// We only send requests
  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    throw UnimplementedError('Nope');
  }

  @override
  Future<void> handleResponse(AtRpcResp response) async {
    sshnpd.logger.info('Got response ${response.payload}');

    if (!completerMap.containsKey(response.reqId)) {
      sshnpd.logger.warning(
        'Ignoring auth check response (completerMap has been cleared)'
        ' from ${sshnpd.policyManagerAtsign}'
        ' : $response',
      );
      return;
    }

    Completer<NPAAuthCheckResponse> completer = completerMap[response.reqId]!;

    if (completer.isCompleted) {
      sshnpd.logger.warning(
        'Ignoring auth check response (received after future completion)'
        ' from ${sshnpd.policyManagerAtsign}'
        ' : $response',
      );
      return;
    }
    switch (response.respType) {
      case AtRpcRespType.ack:
        // We don't complete the future when we get an ack
        sshnpd.logger.info(
          'Got ack from ${sshnpd.policyManagerAtsign}'
          ' : $response',
        );
        break;
      case AtRpcRespType.success:
        sshnpd.logger.info(
          'Got auth check response from ${sshnpd.policyManagerAtsign}'
          ' : $response',
        );
        completer.complete(NPAAuthCheckResponse.fromJson(response.payload));
        break;
      default:
        sshnpd.logger.warning(
          'Got non-success auth check response from ${sshnpd.policyManagerAtsign}'
          ' : $response',
        );
        completer.complete(
          NPAAuthCheckResponse(
            authorized: false,
            message: response.message ?? 'Got non-success response $response',
            permitOpen: [],
          ),
        );
        break;
    }
  }
}

/// Just a data structure
class AesKeyBundle {
  /// AES key, base64 encoded
  final String aesKey;

  /// encrypted copy of [aesKey], base64 encoded
  final String aesKeyEncrypted;

  /// IV, base64 encoded
  final String iv;

  /// encrypted copy of [iv], base64 encoded
  final String ivEncrypted;

  AesKeyBundle({
    required this.aesKey,
    required this.aesKeyEncrypted,
    required this.iv,
    required this.ivEncrypted,
  });
}

Future<AesKeyBundle> genBundle(
  EncryptionKeyType encKeyType,
  String encPubKey,
) async {
  String aesKey, aesKeyEncrypted, iv, ivEncrypted;

  aesKey = AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
  iv = base64Encode(AtChopsUtil.generateRandomIV(16).ivBytes);

  switch (encKeyType) {
    case EncryptionKeyType.rsa2048:
      AtChops atChops = AtChopsImpl(
        AtChopsKeys.create(AtEncryptionKeyPair.create(encPubKey, 'n/a'), null),
      );
      aesKeyEncrypted = atChops.encryptString(aesKey, encKeyType).result;
      ivEncrypted = atChops.encryptString(iv, encKeyType).result;
      break;
    default:
      throw Exception('No handling for ephemeralPKType $encKeyType');
  }

  return AesKeyBundle(
    aesKey: aesKey,
    aesKeyEncrypted: aesKeyEncrypted,
    iv: iv,
    ivEncrypted: ivEncrypted,
  );
}
