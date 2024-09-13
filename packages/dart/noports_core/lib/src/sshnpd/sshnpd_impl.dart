import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/src/common/openssh_binary_path.dart';
import 'package:noports_core/src/srv/srv.dart';
import 'package:noports_core/src/sshnp/impl/notification_request_message.dart';
import 'package:noports_core/sshnpd.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/src/version.dart';
import 'package:uuid/uuid.dart';

@protected
class SshnpdImpl implements Sshnpd {
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
  String get deviceAtsign => atClient.getCurrentAtSign()!;

  @override
  final List<String> managerAtsigns;

  @override
  final String? policyManagerAtsign;

  @override
  final SupportedSshClient sshClient;

  @override
  final bool makeDeviceInfoVisible;

  @override
  final bool addSshPublicKeys;

  @override
  final int localSshdPort;

  @override
  final String sshPublicKeyPermissions;
  final String _sshPublicKeySeparator; // ' ' if there are permissions else ''

  @override
  final String ephemeralPermissions;

  @override
  final SupportedSshAlgorithm sshAlgorithm;

  @override
  final String deviceGroup;

  @override
  @visibleForTesting
  bool initialized = false;

  /// The version of whatever program is using this library.
  @override
  final String version;

  /// State variables used by [_notificationHandler]
  String _privateKey = '';

  static const String commandToSend = 'sshd';

  AuthChecker? authChecker;

  late final Map<String, dynamic> pingResponse;

  final List<String> permitOpen;

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
    required this.ephemeralPermissions,
    required this.sshAlgorithm,
    required this.deviceGroup,
    required this.version,
    required this.permitOpen,
    this.authChecker,
  }) : _sshPublicKeySeparator = (sshPublicKeyPermissions.isEmpty ? "" : " ") {
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
      },
      'allowedServices': permitOpen,
    };
  }

  static Future<Sshnpd> fromCommandLineArgs(
    List<String> args, {
    AtClient? atClient,
    FutureOr<AtClient> Function(SshnpdParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    required String version,
  }) async {
    try {
      SshnpdParams p;
      try {
        p = await SshnpdParams.fromArgs(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      // Check atKeyFile selected exists
      if (!await File(p.atKeysFilePath).exists()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
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
        policyManagerAtsign: p.policyManagerAtsign,
        sshClient: p.sshClient,
        makeDeviceInfoVisible: p.makeDeviceInfoVisible,
        addSshPublicKeys: p.addSshPublicKeys,
        localSshdPort: p.localSshdPort,
        sshPublicKeyPermissions: p.sshPublicKeyPermissions,
        ephemeralPermissions: p.ephemeralPermissions,
        sshAlgorithm: p.sshAlgorithm,
        deviceGroup: p.deviceGroup,
        version: version,
        permitOpen: p.permitOpen.split(',').map((e) => e.trim()).toList(),
      );

      if (p.verbose) {
        sshnpd.logger.logger.level = Level.INFO;
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

    initialized = true;
  }

  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }

    await _shareUsername();

    logger.info('Starting heartbeat');
    startHeartbeat();

    logger.info('Subscribing to $device\\.${DefaultArgs.namespace}@');
    atClient.notificationService
        .subscribe(
            regex: '$device\\.${DefaultArgs.namespace}@', shouldDecrypt: true)
        .listen(
          _notificationHandler,
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

    // If using a policy service, tell it we're here
    await _sendHeartbeatToPolicy();
    Timer.periodic(
      DefaultSshnpdArgs.policyHeartbeatFrequency,
      (_) async => await _sendHeartbeatToPolicy(),
    );

    logger.info('Done');
  }

  void startHeartbeat() {
    bool lastHeartbeatOk = true;
    Timer.periodic(Duration(seconds: 15), (timer) async {
      String? resp;
      try {
        resp = await atClient
            .getRemoteSecondary()
            ?.atLookUp
            .executeCommand('noop:0\n');
      } catch (_) {}
      if (resp == null || !resp.startsWith('data:ok')) {
        if (lastHeartbeatOk) {
          logger.shout('connection lost');
        }
        lastHeartbeatOk = false;
      } else {
        if (!lastHeartbeatOk) {
          logger.shout('connection available');
        }
        lastHeartbeatOk = true;
      }
    });
  }

  /// Notification handler for sshnpd
  void _notificationHandler(AtNotification notification) async {
    NPAAuthCheckResponse auth = await authCheck(notification);
    if (!auth.authorized) {
      // TODO IF $someConditions apply then send a 'nice' error
      // TODO message notification back to the requester
      logger.shout('Notification ignored from ${notification.from}'
          ' which is not authorized: ${auth.message}'
          ' Notification value was ${notification.value}');
      return;
    }

    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.${DefaultArgs.namespace}${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();

    logger.info('Received: $notificationKey');
    switch (notificationKey) {
      case 'privatekey':
        logger.info(
            'Private Key received from ${notification.from} notification id : ${notification.id}');
        _privateKey = notification.value!;
        break;

      case 'sshpublickey':
        await _handlePublicKeyNotification(notification);
        break;

      case 'sshd':
        logger.info(
            'LEGACY $notificationKey request received from ${notification.from}'
            ' ( ${notification.value} )');
        _handleLegacySshRequestNotification(notification);
        break;

      case 'ping':
        logger.info('$notificationKey received from ${notification.from}'
            ' ( ${notification.value} )');
        _handlePingNotification(notification);
        break;

      case 'ssh_request':
        logger.info('$notificationKey received from ${notification.from}'
            ' ( ${notification.value} )');
        _handleSshRequestNotification(notification);
        break;

      case 'npt_request':
        logger.info('$notificationKey received from ${notification.from}'
            ' ( ${notification.value} )');
        _handleNptRequestNotification(notification, auth);
        break;
    }
  }

  Future<NPAAuthCheckResponse> authCheck(AtNotification notification) async {
    const authTimeoutSeconds = 10;
    String client = notification.from;

    if (managerAtsigns.contains(client)) {
      return NPAAuthCheckResponse(
        authorized: true,
        message: '$client is in --managers list',
        permitOpen: ['*:*'],
      );
    }
    if (policyManagerAtsign == client) {
      return NPAAuthCheckResponse(
        authorized: true,
        message: '$client is the policy manager',
        permitOpen: ['*:*'],
      );
    }

    if (authChecker != null) {
      late NPAAuthCheckResponse resp;
      try {
        logger.info('Asking $policyManagerAtsign'
            ' whether $client may connect to this daemon');
        resp = await authChecker!
            .mayConnect(clientAtsign: client)
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
      message: '$client is not in --managers list',
      permitOpen: [],
    );
  }

  void _handlePingNotification(AtNotification notification) {
    logger.info(
        'ping received from ${notification.from} notification id : ${notification.id}');

    var atKey = AtKey()
      ..key = 'heartbeat.$device'
      ..sharedBy = deviceAtsign
      ..sharedWith = notification.from
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..ttl = 10000 // allow only ten seconds before this record expires
        ..namespaceAware = true);

    /// send a heartbeat back
    unawaited(
      _notify(
        atKey: atKey,
        value: jsonEncode(pingResponse),
      ),
    );
  }

  Future<void> _handlePublicKeyNotification(AtNotification notification) async {
    if (!addSshPublicKeys) {
      logger.info(
          'Ignoring sshpublickey from ${notification.from} notification id : ${notification.id}');
      return;
    }

    try {
      final String sshPublicKey;
      logger.info(
          'ssh Public Key received from ${notification.from} notification id : ${notification.id}');
      sshPublicKey = notification.value!;

      // Check to see if the ssh public key is
      // supported keys by the dartssh2 package
      if (!sshPublicKey.startsWith(RegExp(
          r'^(ecdsa-sha2-nistp)|(rsa-sha2-)|(ssh-rsa)|(ssh-ed25519)|(ecdsa-sha2-nistp)'))) {
        throw ('$sshPublicKey does not look like a public key');
      }

      // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
      var authKeysFilePath = [homeDirectory, '.ssh', 'authorized_keys']
          .join(Platform.pathSeparator);
      var authKeys = File(authKeysFilePath);

      var authKeysContent = await authKeys.readAsString();

      if (!authKeysContent.contains(sshPublicKey)) {
        authKeys.writeAsStringSync(
          '$sshPublicKeyPermissions$_sshPublicKeySeparator$sshPublicKey',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      logger.severe("Error writing to"
          " $username's .ssh/authorized_keys file : $e");
    }
  }

  void _handleNptRequestNotification(
    AtNotification notification,
    NPAAuthCheckResponse auth,
  ) async {
    String requestingAtsign = notification.from;

    // Extract the NPT request payload.
    late final Map envelope;
    late final NptSessionRequest req;
    try {
      envelope = jsonDecode(notification.value!);
      assertValidValue(envelope, 'signature', String);
      assertValidValue(envelope, 'hashingAlgo', String);
      assertValidValue(envelope, 'signingAlgo', String);

      Map<String, dynamic> params = envelope['payload'];

      req = NptSessionRequest.fromJson(params);
    } catch (e) {
      logger.warning(
          'Failed to extract parameters from notification value "${notification.value}" with error : $e');
      return;
    }

    try {
      await verifyEnvelopeSignature(
          atClient, requestingAtsign, logger, envelope);
    } catch (e) {
      logger.shout('Failed to verify signature of msg from $requestingAtsign');
      logger.shout('Exception: $e');
      logger.shout('Notification value: ${notification.value}');

      // Notify noports client that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: req.sessionId),
        value: 'Signature not verified: $e',
        sessionId: req.sessionId,
      );

      return;
    }

    String requested = '${req.requestedHost}:${req.requestedPort}';
    // Check if this *daemon* allows connections to the requested host / port
    if (!_permittedToOpen(permitOpen, req)) {
      // Notify noports client that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: req.sessionId),
        value: 'Daemon does not permit connections to $requested',
        sessionId: req.sessionId,
      );

      return;
    }

    // Check if this *client* is allowed connections to the requested host / port
    if (!_permittedToOpen(auth.permitOpen, req)) {
      // Notify noports client that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: req.sessionId),
        value: 'Client is not permitted connections to $requested',
        sessionId: req.sessionId,
      );

      return;
    }

    // Start our side of the tunnel
    await startNpt(
      requestingAtsign: requestingAtsign,
      req: req,
    );
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
  }) async {
    logger.info(
        'Setting up ports for tunnel session using ${sshClient.name} ($sshClient) from: $requestingAtsign session: ${req.sessionId}');

    // TODO Loads of duplicated code here with startDirectSsh, duplicate code needs to be factored out
    //      e.g. making the rvdAuthString; generating AES and IV and encrypting them

    try {
      String? rvdAuthString;
      if (req.authenticateToRvd) {
        // TODO refactor duplicate code from startDirectSsh
        rvdAuthString = signAndWrapAndJsonEncode(atClient, {
          'sessionId': req.sessionId,
          'clientNonce': req.clientNonce,
          'rvdNonce': req.rvdNonce,
        });
      }

      String? sessionAESKey, sessionAESKeyEncrypted;
      String? sessionIV, sessionIVEncrypted;
      if (req.encryptRvdTraffic) {
        // TODO refactor duplicate code from startDirectSsh
        // 256-bit AES, 128-bit IV
        sessionAESKey =
            AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
        sessionIV = base64Encode(AtChopsUtil.generateRandomIV(16).ivBytes);
        late EncryptionKeyType ect;
        try {
          ect = EncryptionKeyType.values.byName(req.clientEphemeralPKType);
        } catch (e) {
          throw Exception(
              'Unknown ephemeralPKType: ${req.clientEphemeralPKType}');
        }
        switch (ect) {
          case EncryptionKeyType.rsa2048:
            AtChops ac = AtChopsImpl(AtChopsKeys.create(
                AtEncryptionKeyPair.create(req.clientEphemeralPK, 'n/a'),
                null));
            sessionAESKeyEncrypted = ac
                .encryptString(sessionAESKey,
                    EncryptionKeyType.values.byName(req.clientEphemeralPKType))
                .result;
            sessionIVEncrypted = ac
                .encryptString(sessionIV,
                    EncryptionKeyType.values.byName(req.clientEphemeralPKType))
                .result;
            break;
          default:
            throw Exception(
                'No handling for ephemeralPKType ${req.clientEphemeralPKType}');
        }
      }
      // Connect to rendezvous point using background process.
      // This program can then exit without causing an issue.
      Process rv = await Srv.exec(
        req.rvdHost,
        req.rvdPort,
        localPort: req.requestedPort,
        bindLocalPort: false,
        localHost: req.requestedHost,
        rvdAuthString: rvdAuthString,
        sessionAESKeyString: sessionAESKey,
        sessionIVString: sessionIV,
        multi: true,
        timeout: req.timeout,
      ).run();
      logger.info('Started rv - pid is ${rv.pid}');

      /// - Send response message to the sshnp client which includes the
      ///   ephemeral private key
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: req.sessionId),
        value: signAndWrapAndJsonEncode(atClient, {
          'status': 'connected',
          'sessionId': req.sessionId,
          'sessionAESKey': sessionAESKeyEncrypted,
          'sessionIV': sessionIVEncrypted,
        }),
        sessionId: req.sessionId,
      );
    } catch (e) {
      logger.severe('startNpt failed with unexpected error : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: req.sessionId),
        value:
            'Failed to start up the daemon side of the srv socket tunnel : $e',
        sessionId: req.sessionId,
      );
    }
  }

  /// If json['direct'] is true, bridge the rvd connection to this device's
  /// [localSshdPort] so that the client can do a 'direct' ssh via the rvd
  ///
  /// **LEGACY behaviour** If json['direct'] is false, start a reverse ssh to
  /// the client device using the `username`, `host`, `port` and `privateKey`
  /// which are also provided in the json payload, and requesting a remote
  /// port forwarding of the provided `remoteForwardPort` to this device's
  /// [localSshdPort].
  void _handleSshRequestNotification(AtNotification notification) async {
    String requestingAtsign = notification.from;

    // Validate the request payload.
    late final Map envelope;
    late final Map params;
    try {
      envelope = jsonDecode(notification.value!);
      assertValidValue(envelope, 'signature', String);
      assertValidValue(envelope, 'hashingAlgo', String);
      assertValidValue(envelope, 'signingAlgo', String);

      params = envelope['payload'] as Map;

      // sessionId, host (of the rvd) and port (of the rvd) are required.
      assertValidValue(params, 'sessionId', String);
      assertValidValue(params, 'host', String);
      assertValidValue(params, 'port', int);

      // v5+ params are not required but must be valid if supplied
      assertNullOrValidValue(params, 'authenticateToRvd', bool);
      assertNullOrValidValue(params, 'clientNonce', String);
      assertNullOrValidValue(params, 'rvdNonce', String);
      assertNullOrValidValue(params, 'encryptRvdTraffic', bool);
      assertNullOrValidValue(params, 'clientEphemeralPK', String);
      assertNullOrValidValue(params, 'clientEphemeralPKType', String);

      // If a reverse ssh (v3, LEGACY BEHAVIOUR) is being requested, then we
      // also require a username (to ssh back to the client), a privateKey (for
      // that ssh) and a remoteForwardPort, to set up the ssh tunnel back to
      // this device from the client side.
      if (params['direct'] != true) {
        assertValidValue(params, 'username', String);
        assertValidValue(params, 'remoteForwardPort', int);
        assertValidValue(params, 'privateKey', String);
      }
    } catch (e) {
      logger.warning(
          'Failed to extract parameters from notification value "${notification.value}" with error : $e');
      return;
    }

    try {
      await verifyEnvelopeSignature(
          atClient, requestingAtsign, logger, envelope);
    } catch (e) {
      logger.shout('Failed to verify signature of msg from $requestingAtsign');
      logger.shout('Exception: $e');
      logger.shout('Notification value: ${notification.value}');
      return;
    }

    if (params['direct'] == true) {
      // direct ssh requested
      await startDirectSsh(
        requestingAtsign: requestingAtsign,
        sessionId: params['sessionId'],
        host: params['host'],
        port: params['port'],
        authenticateToRvd: params['authenticateToRvd'],
        clientNonce: params['clientNonce'],
        rvdNonce: params['rvdNonce'],
        encryptRvdTraffic: params['encryptRvdTraffic'],
        clientEphemeralPK: params['clientEphemeralPK'],
        clientEphemeralPKType: params['clientEphemeralPKType'],
      );
    } else {
      // reverse ssh requested
      await startReverseSsh(
          requestingAtsign: requestingAtsign,
          sessionId: params['sessionId'],
          host: params['host'],
          port: params['port'],
          username: params['username'],
          privateKey: params['privateKey'],
          remoteForwardPort: params['remoteForwardPort']);
    }
  }

  /// ssh through to the remote device with the information we've received
  void _handleLegacySshRequestNotification(AtNotification notification) async {
    String requestingAtsign = notification.from;

    /// notification value is `$remoteForwardPort $remotePort $username $remoteHost $sessionId`
    List<String> sshList = notification.value!.split(' ');
    var remoteForwardPort = sshList[0];
    var port = sshList[1];
    var username = sshList[2];
    var host = sshList[3];
    late String sessionId;
    if (sshList.length == 5) {
      // sshnp >=2.0.0 clients send sessionId
      sessionId = sshList[4];
    } else {
      // sshnp <2.0.0 clients do not send sessionId, it's generated here
      sessionId = Uuid().v4();
    }

    await startReverseSsh(
        requestingAtsign: requestingAtsign,
        sessionId: sessionId,
        username: username,
        host: host,
        port: int.parse(port),
        privateKey: _privateKey,
        remoteForwardPort: int.parse(remoteForwardPort));
  }

  /// - Starts an srv process bridging the rvd to localhost:$localSshdPort
  /// - Generates an ephemeral keypair and adds its public key to the
  ///   `authorized_keys` file, limiting permissions (e.g. hosts and ports
  ///   which can be forwarded to) as per the `--ephemeral-permissions` option
  /// - Sends response message to the sshnp client which includes the
  ///   ephemeral private key
  /// - starts a timer to remove the ephemeral key from `authorized_keys`
  ///   after 15 seconds
  Future<void> startDirectSsh({
    required String requestingAtsign,
    required String sessionId,
    required String host,
    required int port,
    required bool? authenticateToRvd,
    required String? clientNonce,
    required String? rvdNonce,
    required bool? encryptRvdTraffic,
    required String? clientEphemeralPK,
    required String? clientEphemeralPKType,
  }) async {
    logger.info(
        'Setting up ports for direct ssh session using ${sshClient.name} ($sshClient) from: $requestingAtsign session: $sessionId');

    authenticateToRvd ??= false;
    encryptRvdTraffic ??= false;
    try {
      String? rvdAuthString;
      if (authenticateToRvd) {
        rvdAuthString = signAndWrapAndJsonEncode(atClient, {
          'sessionId': sessionId,
          'clientNonce': clientNonce,
          'rvdNonce': rvdNonce,
        });
      }

      String? sessionAESKey, sessionAESKeyEncrypted;
      String? sessionIV, sessionIVEncrypted;
      if (encryptRvdTraffic) {
        if (clientEphemeralPK == null || clientEphemeralPKType == null) {
          throw Exception(
              'encryptRvdTraffic was requested, but no client ephemeral public key / key type was provided');
        }
        // 256-bit AES, 128-bit IV
        sessionAESKey =
            AtChopsUtil.generateSymmetricKey(EncryptionKeyType.aes256).key;
        sessionIV = base64Encode(AtChopsUtil.generateRandomIV(16).ivBytes);
        late EncryptionKeyType ect;
        try {
          ect = EncryptionKeyType.values.byName(clientEphemeralPKType);
        } catch (e) {
          throw Exception('Unknown ephemeralPKType: $clientEphemeralPKType');
        }
        switch (ect) {
          case EncryptionKeyType.rsa2048:
            AtChops ac = AtChopsImpl(AtChopsKeys.create(
                AtEncryptionKeyPair.create(clientEphemeralPK, 'n/a'), null));
            sessionAESKeyEncrypted = ac
                .encryptString(sessionAESKey,
                    EncryptionKeyType.values.byName(clientEphemeralPKType))
                .result;
            sessionIVEncrypted = ac
                .encryptString(sessionIV,
                    EncryptionKeyType.values.byName(clientEphemeralPKType))
                .result;
            break;
          default:
            throw Exception(
                'No handling for ephemeralPKType $clientEphemeralPKType');
        }
      }
      // Connect to rendezvous point using background process.
      // This program can then exit without causing an issue.
      Process rv = await Srv.exec(
        host,
        port,
        localPort: localSshdPort,
        bindLocalPort: false,
        rvdAuthString: rvdAuthString,
        sessionAESKeyString: sessionAESKey,
        sessionIVString: sessionIV,
        timeout: DefaultArgs.srvTimeout,
      ).run();
      logger.info('Started rv - pid is ${rv.pid}');

      LocalSshKeyUtil keyUtil = LocalSshKeyUtil();

      /// Generate the ephemeral key pair which the client will use for the
      /// initial tunnel ssh session
      AtSshKeyPair tunnelKeyPair = await keyUtil.generateKeyPair(
          algorithm: sshAlgorithm, identifier: 'ephemeral_$sessionId');

      await keyUtil.authorizePublicKey(
        sshPublicKey: tunnelKeyPair.publicKeyContents,
        localSshdPort: localSshdPort,
        sessionId: sessionId,
        permissions: ephemeralPermissions,
      );

      /// Remove the ephemeral keypair from persistent storage
      try {
        await keyUtil.deleteKeyPair(identifier: tunnelKeyPair.identifier);
      } catch (e) {
        logger.shout('Failed to delete ephemeral keyPair: $e');
      }

      /// - Send response message to the sshnp client which includes the
      ///   ephemeral private key
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: sessionId),
        value: signAndWrapAndJsonEncode(atClient, {
          'status': 'connected',
          'sessionId': sessionId,
          'ephemeralPrivateKey': tunnelKeyPair.privateKeyContents,
          'sessionAESKey': sessionAESKeyEncrypted,
          'sessionIV': sessionIVEncrypted,
        }),
        sessionId: sessionId,
      );

      /// - start a timer to remove the ephemeral key from `authorized_keys`
      ///   after 15 seconds
      Timer(const Duration(seconds: 15),
          () => keyUtil.deauthorizePublicKey(sessionId));
    } catch (e) {
      logger.severe('startDirectSsh failed with unexpected error : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: sessionId),
        value:
            'Failed to start up the daemon side of the srv socket tunnel : $e',
        sessionId: sessionId,
      );
    }
  }

  Future<void> startReverseSsh(
      {required String requestingAtsign,
      required String sessionId,
      required String host,
      required int port,
      required String username,
      required String privateKey,
      required int remoteForwardPort}) async {
    logger.info(
        'Starting reverse ssh session for $username to $host on port $port with forwardRemote of $remoteForwardPort');
    logger.shout(
        'Starting reverse ssh session using ${sshClient.name} ($sshClient) from: $requestingAtsign session: $sessionId');

    try {
      bool success = false;
      String? errorMessage;

      switch (sshClient) {
        case SupportedSshClient.openssh:
          (success, errorMessage) = await reverseSshViaExec(
              host: host,
              port: port,
              sessionId: sessionId,
              username: username,
              remoteForwardPort: remoteForwardPort,
              requestingAtsign: requestingAtsign,
              privateKey: privateKey);
          break;
        case SupportedSshClient.dart:
          (success, errorMessage) = await reverseSshViaSSHClient(
              host: host,
              port: port,
              sessionId: sessionId,
              username: username,
              remoteForwardPort: remoteForwardPort,
              requestingAtsign: requestingAtsign,
              privateKey: privateKey);
          break;
      }

      if (!success) {
        errorMessage ??= 'Failed to forward remote port $remoteForwardPort';
        logger.warning(errorMessage);
        // Notify sshnp that this session is NOT connected
        await _notify(
          atKey: _createResponseAtKey(
              requestingAtsign: requestingAtsign, sessionId: sessionId),
          value: '$errorMessage (use --local-port to specify unused port)',
          sessionId: sessionId,
        );
      } else {
        /// Notify sshnp that the connection has been made
        await _notify(
          atKey: _createResponseAtKey(
              requestingAtsign: requestingAtsign, sessionId: sessionId),
          value: 'connected',
          sessionId: sessionId,
        );
      }
    } catch (e) {
      logger.severe('SSH Client failure : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey: _createResponseAtKey(
            requestingAtsign: requestingAtsign, sessionId: sessionId),
        value: 'Remote SSH Client failure : $e',
        sessionId: sessionId,
      );
    }
  }

  AtKey _createResponseAtKey(
      {required String requestingAtsign, required String sessionId}) {
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

  /// Reverse ssh using SSHClient.
  /// We will ssh outwards with a remote port forwarding to allow a client on
  /// the other side to ssh to [localSshdPort] here.
  Future<(bool, String?)> reverseSshViaSSHClient(
      {required String host,
      required int port,
      required String sessionId,
      required String username,
      required int remoteForwardPort,
      required String requestingAtsign,
      required String privateKey}) async {
    late final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(host, port);
    } catch (e) {
      return (false, 'Failed to open socket to $host:$port : $e');
    }

    late final SSHClient client;
    try {
      client = SSHClient(
        socket,
        username: username,
        identities: [
          // A single private key file may contain multiple keys.
          ...SSHKeyPair.fromPem(privateKey)
        ],
      );
    } catch (e) {
      return (
        false,
        'Failed to create SSHClient for $username@$host:$port : $e'
      );
    }

    try {
      await client.authenticated;
    } catch (e) {
      return (false, 'Failed to authenticate as $username@$host:$port : $e');
    }

    /// Do the port forwarding
    final SSHRemoteForward? forward;
    try {
      forward = await client.forwardRemote(port: remoteForwardPort);
    } catch (e) {
      return (false, 'Failed to request forwardRemote : $e');
    }

    if (forward == null) {
      return (false, 'Failed to forward remote port $remoteForwardPort');
    }

    int counter = 0;
    bool shouldStop = false;

    /// Set up time to check to see if all connections are down
    Timer.periodic(Duration(seconds: 15), (timer) async {
      if (counter == 0) {
        client.close();
        await client.done;
        shouldStop = true;
        timer.cancel();
        logger.shout('$sessionId | ssh session complete');
      }
    });

    /// Answer ssh requests until none are left open
    unawaited(Future.delayed(Duration(milliseconds: 0), () async {
      await for (final connection in forward!.connections) {
        counter++;
        final socket = await Socket.connect('localhost', localSshdPort);

        unawaited(
          connection.stream.cast<List<int>>().pipe(socket).whenComplete(
            () async {
              counter--;
            },
          ),
        );
        unawaited(socket.cast<List<int>>().pipe(connection.sink));
        if (shouldStop) break;
      }
    }).catchError((e) {
      logger.shout(
          '$sessionId | reverseSshViaSSHClient | error from forward connections handler $e');
    }));

    return (true, null);
  }

  /// Reverse ssh by executing ssh directly on the host.
  /// We will ssh outwards with a remote port forwarding to allow a client on
  /// the other side to ssh to [localSshdPort] here.
  Future<(bool, String?)> reverseSshViaExec(
      {required String host,
      required int port,
      required String sessionId,
      required String username,
      required int remoteForwardPort,
      required String requestingAtsign,
      required String privateKey}) async {
    final pemFile = File('/tmp/.${Uuid().v4()}');
    if (!privateKey.endsWith('\n')) {
      privateKey += '\n';
    }
    pemFile.writeAsStringSync(privateKey);
    await Process.run('chmod', ['go-rwx', pemFile.absolute.path]);

    // When we receive notification 'sshd', WE are going to ssh to the host and port provided by sshnp
    // which could be the host and port of a client machine, or the host and port of an srvd which is
    // joined via socket connector to the client machine. Let's call it targetHostName/Port
    //
    // so: ssh username@targetHostName -p targetHostPort
    //
    // We need to use the private key which the client sent to us (and we just stored in a tmp file)
    // This is done by adding '-i <pemFile>' to the ssh command
    //
    // When we make the connection (remember we are the client) we want to tell the client
    // to listen on some port and forward all connections to that port to sshnpd's [localSshdPort]
    // The incantation for that is -R $clientHostPort:localhost:$localSshdPort
    //
    // We will disable strict host checking since we don't know what hosts we're going to be
    // connecting to. Instead, we'll accept new hostnames but the checks will still be executed
    // if the host identity has changed.
    // -o StrictHostKeyChecking=accept-new
    //
    // We don't want keyboard interactive: we add -o BatchMode=yes
    //
    // For convenience of this Sshnpd, we would like to know as quickly
    // as possible if the ssh connection has succeeded or not.
    // So we will add options 'ForkAfterAuthentication=yes' and also
    // 'ExitOnForwardFailure=yes' so that it won't fork until after
    // all of the forwarding has been successfully set up.
    // This allows us to do a simple Process.start() knowing we will get an exit
    // code 0 promptly if the ssh connection has succeeded, and the actual ssh
    // connection can run happily in the background.
    //
    // Lastly, we want to ensure that if the connection isn't used then it closes after 15 seconds
    // or once the last connection via the remote port has ended. For that we append 'sleep 15' to
    // the ssh command.
    List<String> args = '$username@$host'
            ' -p $port'
            ' -i ${pemFile.absolute.path}'
            ' -R $remoteForwardPort:localhost:$localSshdPort'
            ' -o LogLevel=VERBOSE'
            ' -t -t'
            ' -o StrictHostKeyChecking=accept-new'
            ' -o IdentitiesOnly=yes'
            ' -o BatchMode=yes'
            ' -o ExitOnForwardFailure=yes'
            ' -f' // fork after authentication
            ' sleep 15'
        .split(' ');
    logger.info('$sessionId | Executing $opensshBinaryPath ${args.join(' ')}');

    // Because of the options we are using, we can wait for this process
    // to complete, because it will exit with exitCode 0 once it has connected
    // successfully
    late int sshExitCode;
    final soutBuf = StringBuffer();
    final serrBuf = StringBuffer();
    try {
      Process process = await Process.start(opensshBinaryPath, args);
      process.stdout.listen((List<int> l) {
        var s = utf8.decode(l);
        soutBuf.write(s);
        logger.info('$sessionId | sshStdOut | $s');
      }, onError: (e) {});
      process.stderr.listen((List<int> l) {
        var s = utf8.decode(l);
        serrBuf.write(s);
        logger.info('$sessionId | sshStdErr | $s');
      }, onError: (e) {});
      sshExitCode = await process.exitCode.timeout(Duration(seconds: 10));
      // ignore: unused_catch_clause
    } on TimeoutException catch (e) {
      sshExitCode = 6464;
    }
    cleanupPemFile(pemFile);

    String? errorMessage;
    if (sshExitCode != 0) {
      if (sshExitCode == 6464) {
        logger.shout(
            '$sessionId | Command timed out: $opensshBinaryPath ${args.join(' ')}');
        errorMessage = 'Failed to establish connection - timed out';
      } else {
        logger.shout('$sessionId | Exit code $sshExitCode from'
            ' $opensshBinaryPath ${args.join(' ')}');
        errorMessage =
            'Failed to establish connection - exit code $sshExitCode';
      }
    }

    return (sshExitCode == 0, errorMessage);
  }

  void cleanupPemFile(File pemFile) {
    /// Clean up tmp file
    if (pemFile.existsSync()) {
      try {
        pemFile.deleteSync();
      } catch (e) {
        logger.shout('Failed to clean up a pem : $e');
      }
    }
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
      NotificationParams.forUpdate(atKey,
          value: value, notificationExpiry: ttln),
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
      ..ttr = -1 // we want this to be cacheable by managerAtsign
      ..ccd = true // we want cached copies to be deleted if the key is deleted
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
      ..ttr = -1 // we want this to be cacheable by managerAtsign
      ..ccd = true // we want cached copies to be deleted if the key is deleted
      ..ttl = ttl // but to expire after 30 days
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

  /// If using a policy service, tell it we're here
  Future<void> _sendHeartbeatToPolicy() async {
    if (policyManagerAtsign != null) {
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
    );
    rpc.start();
  }

  @override
  Future<NPAAuthCheckResponse> mayConnect(
      {required String clientAtsign}) async {
    // We're caching auth checks for 30 seconds so we don't bombard the
    // auth server unnecessarily.
    if (authCheckCache.containsKey(clientAtsign)) {
      return completerMap[authCheckCache[clientAtsign]!]!.future;
    }
    AtRpcReq request = AtRpcReq.create(NPAAuthCheckRequest(
            daemonAtsign: sshnpd.deviceAtsign,
            daemonDeviceName: sshnpd.device,
            daemonDeviceGroupName: sshnpd.deviceGroup,
            clientAtsign: clientAtsign)
        .toJson());

    completerMap[request.reqId] = Completer<NPAAuthCheckResponse>();
    authCheckCache[clientAtsign] = request.reqId;

    // To keep memory tidy, we'll clear this request and its cached response
    // after 15 seconds
    Future.delayed(Duration(seconds: 15), () {
      completerMap.remove(request.reqId);
      authCheckCache.remove(clientAtsign);
    });

    sshnpd.logger.info(
        'Sending auth check request to sshnpa at ${sshnpd.policyManagerAtsign} : $request');
    await rpc.sendRequest(
        toAtSign: sshnpd.policyManagerAtsign!, request: request);
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
          ' : $response');
      return;
    }

    Completer<NPAAuthCheckResponse> completer = completerMap[response.reqId]!;

    if (completer.isCompleted) {
      sshnpd.logger.warning(
          'Ignoring auth check response (received after future completion)'
          ' from ${sshnpd.policyManagerAtsign}'
          ' : $response');
      return;
    }
    switch (response.respType) {
      case AtRpcRespType.ack:
        // We don't complete the future when we get an ack
        sshnpd.logger.info('Got ack from ${sshnpd.policyManagerAtsign}'
            ' : $response');
        break;
      case AtRpcRespType.success:
        sshnpd.logger
            .info('Got auth check response from ${sshnpd.policyManagerAtsign}'
                ' : $response');
        completer.complete(NPAAuthCheckResponse.fromJson(response.payload));
        break;
      default:
        sshnpd.logger.warning(
            'Got non-success auth check response from ${sshnpd.policyManagerAtsign}'
            ' : $response');
        completer.complete(NPAAuthCheckResponse(
          authorized: false,
          message: response.message ?? 'Got non-success response $response',
          permitOpen: [],
        ));
        break;
    }
  }
}
