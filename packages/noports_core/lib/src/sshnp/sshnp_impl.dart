import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_commons/at_builders.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:noports_core/sshrvd.dart';
import 'package:noports_core/utils.dart';
import 'package:uuid/uuid.dart';

export 'forward_direction/sshnp_forward_direction.dart';
export 'forward_direction/sshnp_forward_dart_impl.dart';
export 'forward_direction/sshnp_forward_exec_impl.dart';

export 'reverse_direction/sshnp_reverse_direction.dart';
export 'reverse_direction/sshnp_reverse_impl.dart';
export 'reverse_direction/sshnp_legacy_impl.dart';

// If you've never seen an abstract implementation before, here it is :P
@protected
abstract class SSHNPImpl implements SSHNP {
  final AtSignLogger logger = AtSignLogger(' sshnp ');

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================

  @override
  final AtClient atClient;
  @override
  final SSHNPParams params;

  final String sessionId;

  // ====================================================================
  // Final instance variables, derived during initialization
  // ====================================================================

  late final String remoteUsername;

  // ====================================================================
  // Volatile instance variables, injected via constructor
  // but possibly modified later on
  // ====================================================================

  /// Host that we will send to sshnpd for it to connect to,
  /// or the atSign of the sshrvd.
  /// If using sshrvd then we will fetch the _actual_ host to use from sshrvd.
  String host;

  /// Port that we will send to sshnpd for it to connect to.
  /// Required if we are not using sshrvd.
  /// If using sshrvd then initial port value will be ignored and instead we
  /// will fetch the port from sshrvd.
  int port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  int localPort;

  /// When using sshrvd, this is fetched from sshrvd during [init]
  /// This is only set when using sshrvd
  /// (i.e. after [getHostAndPortFromSshrvd] has been called)
  int? sshrvdPort;

  // ====================================================================
  // Status indicators (Available in the public API)
  // ====================================================================

  @protected
  final Completer<void> doneCompleter = Completer<void>();
  @override
  Future<void> get done => doneCompleter.future;

  bool _initializeStarted = false;
  @protected
  bool get initializeStarted => _initializeStarted;
  @protected
  final Completer<void> initializedCompleter = Completer<void>();
  @override
  Future<void> get initialized => initializedCompleter.future;

  // ====================================================================
  // Internal state variables
  // ====================================================================

  /// true once we have received any response (success or error) from sshnpd
  @visibleForTesting
  bool sshnpdAck = false;

  /// true once we have received an error response from sshnpd
  @protected
  bool sshnpdAckErrors = false;

  /// true once we have received a response from sshrvd
  @visibleForTesting
  bool sshrvdAck = false;

  @protected
  late String ephemeralPrivateKey;

  // ====================================================================
  // Getters for derived values
  // ====================================================================

  String get clientAtSign => atClient.getCurrentAtSign()!;
  String get sshnpdAtSign => params.sshnpdAtSign;

  static String getNamespace(String device) => '$device.sshnp';
  String get namespace => getNamespace(params.device);

  // ====================================================================
  // Constructor and Initialization
  // ====================================================================

  SSHNPImpl({
    required this.atClient,
    required this.params,
    SSHRVGenerator? sshrvGenerator,
    bool? shouldInitialize = true,
  })  : sessionId = Uuid().v4(),
        host = params.host,
        port = params.port,
        localPort = params.localPort {
    /// Set the logger level to shout
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    if (params.verbose) {
      logger.logger.level = Level.INFO;
    }

    /// Set the namespace to the device's namespace
    AtClientPreference preference =
        atClient.getPreferences() ?? AtClientPreference();
    preference.namespace = '${params.device}.sshnp';
    atClient.setPreferences(preference);

    /// Also call init
    if (shouldInitialize ?? true) init();
  }

  @override
  Future<void> init() async {
    logger.info('Initializing SSHNPImpl');
    if (_initializeStarted) {
      logger.warning('Cancelling initialization: Already started');
      return;
    } else {
      _initializeStarted = true;
    }

    // Schedule a cleanup on exit
    unawaited(doneCompleter.future.then((_) async {
      logger.info('SSHNPImpl done');
      await cleanUp();
    }));

    try {
      if (!(await atSignIsActivated(atClient, sshnpdAtSign))) {
        logger.severe('Device address $sshnpdAtSign is not activated.');
        throw ('Device address $sshnpdAtSign is not activated.');
      }
    } catch (e, s) {
      throw SSHNPError(e, stackTrace: s);
    }

    // Start listening for response notifications from sshnpd
    logger.info('Subscribing to notifications on $sessionId.$namespace@');
    atClient.notificationService
        .subscribe(regex: '$sessionId.$namespace@', shouldDecrypt: true)
        .listen(handleSshnpdResponses);

    remoteUsername = params.remoteUsername ?? await fetchRemoteUserName();

    // find a spare local port
    if (localPort == 0) {
      logger.info('Finding a spare local port');
      try {
        ServerSocket serverSocket =
            await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        localPort = serverSocket.port;
        await serverSocket.close();
      } catch (e, s) {
        logger.info('Unable to find a spare local port');
        throw SSHNPError('Unable to find a spare local port',
            error: e, stackTrace: s);
      }
    }

    await sharePublicKeyWithSshnpdIfRequired().catchError((e, s) {
      throw SSHNPError(
        'Unable to share ssh public key with sshnpd',
        error: e,
        stackTrace: s,
      );
    });

    // If host has an @ then contact the sshrvd service for some ports
    if (host.startsWith('@')) {
      logger.info('Host is an atSign, fetching host and port from sshrvd');
      await getHostAndPortFromSshrvd().catchError((e, s) {
        throw SSHNPError(
          'Unable to get host and port from sshrvd',
          error: e,
          stackTrace: s,
        );
      });
    }

    logger.finer('Base initialization complete');
    // N.B. Don't complete initialization here, subclasses will do that
    // This is in case they need to implement further initialization steps
  }

  @protected
  void completeInitialization() {
    if (initializedCompleter.isCompleted) return;
    logger.info('Completing initialization');
    initializedCompleter.complete();
  }

  @visibleForTesting
  void handleSshnpdResponses(AtNotification notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$namespace${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');

    bool connected = false;

    if (notification.value == 'connected') {
      connected = true;
    } else if (notification.value?.startsWith('{') ?? false) {
      late final Map envelope;
      late final Map daemonResponse;
      try {
        envelope = jsonDecode(notification.value!);
        assertValidValue(envelope, 'signature', String);
        assertValidValue(envelope, 'hashingAlgo', String);
        assertValidValue(envelope, 'signingAlgo', String);

        daemonResponse = envelope['payload'] as Map;
        assertValidValue(daemonResponse, 'sessionId', String);
        assertValidValue(daemonResponse, 'ephemeralPrivateKey', String);
      } catch (e) {
        logger.warning(
            'Failed to extract parameters from notification value "${notification.value}" with error : $e');
        sshnpdAck = true;
        sshnpdAckErrors = true;
        return;
      }

      try {
        await verifyEnvelopeSignature(atClient, sshnpdAtSign, logger, envelope);
      } catch (e) {
        logger.shout('Failed to verify signature of msg from $sshnpdAtSign');
        logger.shout('Exception: $e');
        logger.shout('Notification value: ${notification.value}');
        sshnpdAck = true;
        sshnpdAckErrors = true;
        return;
      }

      ephemeralPrivateKey = daemonResponse['ephemeralPrivateKey'];
      connected = true;
    }

    if (connected) {
      logger.info('Session $sessionId connected successfully');
      sshnpdAck = true;
    } else {
      sshnpdAck = true;
      sshnpdAckErrors = true;
    }
  }

  // ====================================================================
  // Internal methods
  // ====================================================================

  Future<void> startAndWaitForInit() async {
    if (!initializedCompleter.isCompleted) {
      // Call init in case it hasn't been called yet
      unawaited(init());
    }
    // Wait for init to complete
    // N.B. must be called this way in case the init call above is not the first init call
    return await initialized;
  }

  @protected
  Future<void> notify(AtKey atKey, String value,
      {String sessionId = ""}) async {
    await atClient.notificationService
        .notify(NotificationParams.forUpdate(atKey, value: value),
            onSuccess: (NotificationResult notification) {
      logger.info(
          'SUCCESS:$notification for: $sessionId with key: ${atKey.toString()}');
    }, onError: (notification) {
      logger.info('ERROR:$notification');
    });
  }

  /// Look up the user name ... we expect a key to have been shared with us by
  /// sshnpd. Let's say we are @human running sshnp, and @daemon is running
  /// sshnpd, then we expect a key to have been shared whose ID is
  /// @human:username.device.sshnp@daemon
  /// Is not called if remoteUserName was set via constructor
  @protected
  Future<String> fetchRemoteUserName() async {
    logger.info('Fetching remote username from sshnpd');
    AtKey userNameRecordID =
        AtKey.fromString('$clientAtSign:username.$namespace$sshnpdAtSign');
    try {
      return (await atClient.get(userNameRecordID)).value as String;
    } catch (e, s) {
      throw SSHNPError(
        "Device unknown, or username not shared\n"
        "hint: make sure the device shares username or set remote username manually",
        error: e,
        stackTrace: s,
      );
    }
  }

  @protected
  Future<void> getHostAndPortFromSshrvd() async {
    atClient.notificationService
        .subscribe(
            regex: '$sessionId.${SSHRVD.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      host = results[0];
      port = int.parse(results[1]);
      sshrvdPort = int.parse(results[2]);
      logger.info('Received host and port from sshrvd: $host:$port');
      logger.info('Set sshrvdPort to: $sshrvdPort');
      sshrvdAck = true;
    });
    logger.info('Started listening for sshrvd response');
    AtKey ourSshrvdIdKey = AtKey()
      ..key = '${params.device}.${SSHRVD.namespace}'
      ..sharedBy = clientAtSign // shared by us
      ..sharedWith = host // shared with the sshrvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttr = -1
        ..ttl = 10000);
    logger.info('Sending notification to sshrvd: $ourSshrvdIdKey');
    await notify(ourSshrvdIdKey, sessionId);

    logger.info('Waiting for sshrvd response');
    int counter = 0;
    while (!sshrvdAck) {
      logger.info('Waiting for sshrvd response: $counter');
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        logger.warning('Timed out waiting for sshrvd response');
        throw ('Connection timeout to sshrvd $host service\nhint: make sure host is valid and online');
      }
    }
  }

  Future<void> sharePublicKeyWithSshnpdIfRequired() async {
    if (!params.sendSshPublicKey) {
      logger.info(
          'Skipped sharing public key with sshnpd: sendSshPublicKey=false');
      return;
    }

    logger.info('Sharing public key with sshnpd');
    try {
      String publicKeyContents = '';
      logger.info('sharing ssh public key: $publicKeyContents');
      if (!publicKeyContents.startsWith('ssh-')) {
        logger.severe('SSH Public Key does not look like a public key file');
        throw ('SSH Public Key does not look like a public key file');
      }
      AtKey sendOurPublicKeyToSshnpd = AtKey()
        ..key = 'sshpublickey'
        ..sharedBy = clientAtSign
        ..sharedWith = sshnpdAtSign
        ..metadata = (Metadata()
          ..ttr = -1
          ..ttl = 10000);
      await notify(sendOurPublicKeyToSshnpd, publicKeyContents);
    } catch (e, s) {
      throw SSHNPError(
        'Error opening or validating public key file or sending to remote atSign',
        error: e,
        stackTrace: s,
      );
    }
  }

  @protected
  Future<bool> waitForDaemonResponse() async {
    logger.finer('Waiting for daemon response');
    int counter = 0;
    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    while (!sshnpdAck) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        return false;
      }
    }
    return true;
  }

  Future<List<AtKey>> _getAtKeysRemote(
      {String? regex,
      String? sharedBy,
      String? sharedWith,
      bool showHiddenKeys = false}) async {
    var builder = ScanVerbBuilder()
      ..sharedWith = sharedWith
      ..sharedBy = sharedBy
      ..regex = regex
      ..showHiddenKeys = showHiddenKeys
      ..auth = true;
    var scanResult = await atClient.getRemoteSecondary()?.executeVerb(builder);
    scanResult = scanResult?.replaceFirst('data:', '') ?? '';
    var result = <AtKey?>[];
    if (scanResult.isNotEmpty) {
      result = List<String>.from(jsonDecode(scanResult)).map((key) {
        try {
          return AtKey.fromString(key);
        } on InvalidSyntaxException {
          logger.severe('$key is not a well-formed key');
        } on Exception catch (e) {
          logger.severe(
              'Exception occurred: ${e.toString()}. Unable to form key $key');
        }
      }).toList();
    }
    result.removeWhere((element) => element == null);
    return result.cast<AtKey>();
  }

  // ====================================================================
  // Public API
  // ====================================================================

  @override
  Future<(Iterable<String>, Iterable<String>, Map<String, dynamic>)>
      listDevices() async {
    // get all the keys device_info.*.sshnpd
    var scanRegex =
        'device_info\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}';

    var atKeys =
        await _getAtKeysRemote(regex: scanRegex, sharedBy: sshnpdAtSign);

    var devices = <String>{};
    var heartbeats = <String>{};
    var info = <String, dynamic>{};

    // Listen for heartbeat notifications
    atClient.notificationService
        .subscribe(
            regex: 'heartbeat\\.$sshnpDeviceNameRegex', shouldDecrypt: true)
        .listen((notification) {
      var deviceInfo = jsonDecode(notification.value ?? '{}');
      var devicename = deviceInfo['devicename'];
      if (devicename != null) {
        heartbeats.add(devicename);
      }
    });

    // for each key, get the value
    for (var entryKey in atKeys) {
      var atValue = await atClient.get(
        entryKey,
        getRequestOptions: GetRequestOptions()..bypassCache = true,
      );
      var deviceInfo = jsonDecode(atValue.value) ?? <String, dynamic>{};

      if (deviceInfo['devicename'] == null) {
        continue;
      }

      var devicename = deviceInfo['devicename'] as String;
      info[devicename] = deviceInfo;

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..ttr = -1
        ..namespaceAware = true;

      var pingKey = AtKey()
        ..key = "ping.$devicename"
        ..sharedBy = clientAtSign
        ..sharedWith = entryKey.sharedBy
        ..namespace = DefaultArgs.namespace
        ..metadata = metaData;

      unawaited(notify(pingKey, 'ping'));

      // Add the device to the base list
      devices.add(devicename);
    }

    // wait for 10 seconds in case any are being slow
    await Future.delayed(const Duration(seconds: 5));

    // The intersection is in place on the off chance that some random device
    // sends a heartbeat notification, but is not on the list of devices
    return (
      devices.intersection(heartbeats),
      devices.difference(heartbeats),
      info,
    );
  }

  @override
  FutureOr<void> cleanUp() {
    logger.info('Cleaning up SSHNPImpl');
    // This is an intentional no-op to allow overrides to safely call super.cleanUp()
  }
}
