import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:at_commons/at_builders.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/subscription_tracking.dart';
import 'package:noports_core/src/events/noports_event_types.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

import '../../../common/features.dart';
import 'daemon_ping_record.dart';

/// enum for sshnpd acknowledgement state
enum SshnpdAck {
  /// sshnpd acknowledged our request
  acknowledged,

  /// sshnpd acknowledged our request and had errors
  acknowledgedWithErrors,

  /// sshnpd did not acknowledge our request
  notAcknowledged,
}

/// This is the generic class which represents the channel between the client
/// and the daemon. It is responsible for sending the request to the daemon and
/// receiving the response from the daemon.
abstract class SshnpdChannel
    with
        AsyncInitialization,
        AtClientBindings,
        AtEventLogger,
        SubscriptionTracking {
  @override
  final logger = AtSignLogger(' SshnpdChannel ');
  @override
  final AtClient atClient;

  final SshnpdChannelParams params;
  final String sessionId;
  final String namespace;

  AtEventConfig? eventLoggingConfig;

  // * Volatile fields set at runtime

  /// State of sshnpd acknowledgement
  @visibleForTesting
  @protected
  SshnpdAck sshnpdAck = SshnpdAck.notAcknowledged;

  Map<String, dynamic>? pingResponse;

  /// What went wrong with the daemon's response, when [sshnpdAck] is
  /// [SshnpdAck.acknowledgedWithErrors].
  String? errorReceived;

  /// The default [pingRecordTimeout].
  static const Duration defaultPingRecordTimeout = Duration(seconds: 5);

  /// How long the client's atServer keeps a ping record.
  static const Duration pingRecordTtl = Duration(days: 30);

  /// How old a ping record grows before a live ping rewrites it unchanged.
  static const Duration pingRecordRefreshAge = Duration(days: 7);

  /// How far ahead of this clock a ping record's time may be, for clock skew,
  /// before a live ping rewrites it unchanged.
  static const Duration pingRecordClockSkew = Duration(minutes: 5);

  /// How long the client waits for its own atServer to read or write the
  /// ping record.
  @visibleForTesting
  Duration pingRecordTimeout = defaultPingRecordTimeout;

  /// The latest live ping answer this process has had from each daemon
  /// device, by client Atsign, daemon Atsign and device.
  static final Map<(Atsign, Atsign, String), DaemonRelayAuthSupport>
      _liveAnswers = {};

  /// Forgets every live ping answer this process has had.
  @visibleForTesting
  static void forgetLiveAnswers() => _liveAnswers.clear();

  (Atsign, Atsign, String) get _daemonDevice => (
        params.clientAtSign.toAtsign(),
        params.sshnpdAtSign.toAtsign(),
        params.device,
      );

  /// The client's own record of this daemon device's last ping response:
  /// `cached.ping.<daemon>.<device>.sshnp@<client>`.
  AtKey get pingRecordKey => AtKey()
    ..key = 'cached.ping.${params.sshnpdAtSign.toAtsign().withoutAt()}'
        '.${params.device}'
    ..namespace = DefaultArgs.namespace
    ..sharedBy = params.clientAtSign.toAtsign()
    ..metadata = (Metadata()..ttl = pingRecordTtl.inMilliseconds);

  /// Whether the ping record was read, absent or not, so may be rewritten.
  bool _pingRecordReadable = false;

  Future<void>? _pingRecordRead;

  /// The one read of the ping record, started on first use.
  Future<void> get _recordRead => _pingRecordRead ??= _readPingRecord();

  DaemonPingRecord? _pingRecord;

  Completer acked = Completer();

  bool _responded = false;

  /// If the daemon supports twinKeys then this gets set to true by the
  /// [featureCheck] function.
  late final bool twinKeys;

  /// What the live ping response says about the daemon's relay
  /// authentication; null until the daemon has answered a ping.
  DaemonRelayAuthSupport? get liveRelayAuthSupport => pingResponse == null
      ? null
      : DaemonRelayAuthSupport.fromPingResponse(pingResponse!);

  /// Whether the live ping response advertised the ESCR relay-auth mode; false
  /// for daemons that predate it, and until the daemon has answered a ping.
  bool get daemonSupportsRelayAuthEscr =>
      liveRelayAuthSupport?.supportsRamEscr ?? false;

  SshnpdChannel({
    required this.atClient,
    required this.params,
    required this.sessionId,
    required this.namespace,
  }) {
    logger.level = params.verbose ? 'info' : 'shout';
  }

  /// Initialization starts the subscription to notifications from the daemon.
  @override
  Future<void> initialize() async {
    String regex = '$sessionId.$namespace${params.sshnpdAtSign}\$';
    logger.info('Starting monitor for notifications with regex: "$regex"');
    track(
      subscribe(
        regex: regex,
        shouldDecrypt: true,
      ).listen(handleSshnpdResponses),
    );
  }

  /// What this process last heard live from this daemon device, or else what
  /// its ping record on the client's own atServer says; null when neither is
  /// known.
  ///
  /// Starts reading the record, which [refreshPingRecord] needs, and waits
  /// for that read, at most [pingRecordTimeout], only when this process has
  /// no live answer. A record that cannot be read or decoded counts as
  /// absent.
  Future<DaemonRelayAuthSupport?> knownRelayAuthSupport() async {
    final Future<void> read = _recordRead;
    final DaemonRelayAuthSupport? live = _liveAnswers[_daemonDevice];
    if (live != null) return live;
    await read;
    return _liveAnswers[_daemonDevice] ?? _pingRecord?.support;
  }

  Future<void> _readPingRecord() async {
    final AtKey key = pingRecordKey;
    final AtValue stored;
    try {
      stored = await atClient
          .get(
            key,
            getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
          )
          .timeout(pingRecordTimeout);
    } on AtKeyNotFoundException {
      _pingRecordReadable = true;
      return;
    } catch (e) {
      logger.warning(
        'Could not read $key, so waiting for the daemon to answer its ping:'
        ' $e',
      );
      return;
    }
    _pingRecordReadable = true;
    try {
      _pingRecord = DaemonPingRecord.decode(stored.value);
    } catch (e) {
      logger.warning(
        'Ignoring $key, which cannot be decoded, so waiting for the daemon to'
        ' answer its ping: $e',
      );
    }
  }

  /// Writes the live ping answer to this daemon device's ping record on the
  /// client's own atServer, when the record is absent or undecodable, says
  /// something else, is older than [pingRecordRefreshAge], or was stored more
  /// than [pingRecordClockSkew] ahead of this clock.
  ///
  /// Writes nothing when the daemon has not answered a ping, or when the
  /// record could not be read. Waits for the record's read and then its
  /// write, each at most [pingRecordTimeout]; a write that fails is logged,
  /// and the session carries on.
  Future<void> refreshPingRecord() async {
    final DaemonRelayAuthSupport? live = liveRelayAuthSupport;
    if (live == null) return;
    await _recordRead;
    if (!_pingRecordReadable) return;
    final DaemonPingRecord? stored = _pingRecord;
    if (stored != null && stored.support == live) {
      final Duration age = DateTime.now().difference(stored.storedAt);
      if (age <= pingRecordRefreshAge && age >= -pingRecordClockSkew) return;
    }
    final AtKey key = pingRecordKey;
    try {
      final bool written = await atClient
          .put(
            key,
            DaemonPingRecord(storedAt: DateTime.now(), support: live).encode(),
            putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
          )
          .timeout(pingRecordTimeout);
      if (!written) {
        logger.warning('The atServer did not write $key');
      }
    } catch (e) {
      logger.warning('Could not write $key: $e');
    }
  }

  /// Main response handler for the daemon's notifications.
  @visibleForTesting
  Future<void> handleSshnpdResponses(AtNotification notification) async {
    if (_responded) {
      logger.warning(
        'Ignoring another response for session $sessionId'
        ' from ${notification.from}',
      );
      return;
    }
    if (_isForAnotherSession(notification)) {
      logger.warning(
        'Ignoring a response for another session from ${notification.from}',
      );
      return;
    }
    _responded = true;
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$namespace@${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');

    try {
      sshnpdAck = await handleSshnpdPayload(notification);
    } catch (e) {
      logger.shout('Failed to read the response for session $sessionId: $e');
      errorReceived = "Failed to read the daemon's response";
      sshnpdAck = SshnpdAck.acknowledgedWithErrors;
    }
    acked.complete();

    if (sshnpdAck == SshnpdAck.acknowledged) {
      logger.info('Session $sessionId connected successfully');
    }
  }

  /// Whether [notification] carries a payload naming a session other than
  /// this one.
  bool _isForAnotherSession(AtNotification notification) {
    try {
      final payload = jsonDecode(notification.value ?? '')['payload'];
      final id = payload is Map ? payload['sessionId'] : null;
      return id is String && id != sessionId;
    } catch (_) {
      return false;
    }
  }

  /// This method is responsible for handling and validating the payload
  /// received from the daemon and setting the [ephemeralPrivateKey] field.
  /// Returns acknowledgement state.
  @protected
  Future<SshnpdAck> handleSshnpdPayload(AtNotification notification);

  /// Wait until we've received an acknowledgement from the daemon, or
  /// have timed out while waiting.
  Future<SshnpdAck> waitForDaemonResponse({int maxWaitMillis = 15000}) async {
    Duration timeout = Duration(milliseconds: maxWaitMillis);
    logger.info(
      'Will wait for a response for up to ${timeout.inSeconds} seconds',
    );
    try {
      await acked.future.timeout(timeout);
    } on TimeoutException catch (_) {}

    logger.info('sshnpdAck: $sshnpdAck');

    if (eventLoggingConfig != null && sshnpdAck == SshnpdAck.acknowledged) {
      await logEvent(
        eventLoggingConfig!,
        SessionEvent.clientConnecting(sessionId: sessionId),
      );
    }

    // Might be nicer to return a Future<SshnpdAck, String>
    // with the String being the failure reason (if any)
    return sshnpdAck;
  }

  /// Send a notification to the daemon with our shared public key.
  /// Does nothing if [params.sendSshPublicKey] is false or if [identityKeyPair]
  /// is null.
  Future<void> sharePublicKeyIfRequired(AtSshKeyPair? identityKeyPair) async {
    if (!params.sendSshPublicKey) {
      logger.info(
        'Skipped sharing public key with sshnpd: sendSshPublicKey=false',
      );
      return;
    }
    if (identityKeyPair == null) {
      logger.info(
        'Skipped sharing public key with sshnpd: no identity key pair set',
      );
      return;
    }

    var publicKeyContents = identityKeyPair.publicKeyContents;

    logger.info('Sharing ssh public key with sshnpd: $publicKeyContents');
    // Check for Supported ssh keypairs from dartssh2 package
    if (!publicKeyContents.startsWith(
      RegExp(
        r'^(ecdsa-sha2-nistp)|(rsa-sha2-)|(ssh-rsa)|(ssh-ed25519)|(ecdsa-sha2-nistp)',
      ),
    )) {
      throw SshnpError('SSH Public Key does not look like a public key file');
    }
    AtKey sendOurPublicKeyToSshnpd = AtKey()
      ..key = 'sshpublickey'
      ..sharedBy = params.clientAtSign
      ..sharedWith = params.sshnpdAtSign
      ..metadata = (Metadata()..ttl = 10000);
    unawaited(
      notify(
        sendOurPublicKeyToSshnpd,
        publicKeyContents,
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
        ttln: Duration(minutes: 1),
      ).onError((e, st) {
        throw SshnpError('Error sending ssh public key to sshnpd: $e');
      }),
    );
  }

  /// Resolve the remote username to use in the ssh session.
  /// If [params.remoteUsername] is set, it will be used.
  /// Otherwise, the username will be fetched from the remote atSign.
  /// Returns null if the username could not be resolved.
  /// Throws [SshnpError] if the device's username is not a plain login name.
  Future<String?> resolveRemoteUsername() async {
    if (params.remoteUsername != null) {
      return params.remoteUsername!;
    }
    AtKey userNameRecordID = AtKey.fromString(
      '${params.clientAtSign}:username.$namespace${params.sshnpdAtSign}',
    );

    final username = (await atClient.get(userNameRecordID).catchError((_) {
      throw SshnpError(
        "Device is hidden or doesn't exist.\n"
        "Hint: If the device is set to hidden, use -u to specify the login username.",
      );
    })).value;
    if (username == null) {
      return null;
    }
    if (username is! String || !_plainLoginName.hasMatch(username)) {
      throw SshnpError(
        "The device's username is not a plain login name.\n"
        "Hint: use -u to specify the login username.",
      );
    }
    return username;
  }

  static final _plainLoginName = RegExp(
    r'^[\p{L}\p{M}\p{N}_.@][\p{L}\p{M}\p{N}_.@-]{0,63}$',
    unicode: true,
  );

  /// Resolve the username to use in the initial ssh tunnel
  /// If [params.tunnelUsername] is set, it will be used.
  /// Otherwise, the username will be set to [remoteUsername]
  Future<String?> resolveTunnelUsername({
    required String? remoteUsername,
  }) async {
    if (params.tunnelUsername != null &&
        params.tunnelUsername!.trim().isNotEmpty) {
      return params.tunnelUsername!;
    } else {
      return remoteUsername;
    }
  }

  Future<List<(DaemonFeature feature, bool supported, String reason)>>
  featureCheck(
    List<DaemonFeature> featuresToCheck, {
    Duration timeout = DefaultArgs.daemonPingTimeoutDuration,
  }) async {
    if (featuresToCheck.isEmpty) {
      return [];
    }
    try {
      pingResponse = await ping().timeout(timeout);
    } on TimeoutException catch (_) {
      throw TimeoutException('Daemon feature check timed out');
    }
    _liveAnswers[_daemonDevice] = liveRelayAuthSupport!;

    // If supportedFeatures was null (i.e. a response from a v4 daemon),
    // then we will assume that "acceptsPublicKeys" is true
    final Map<String, dynamic> daemonFeatures =
        pingResponse!['supportedFeatures'] ??
        {DaemonFeature.acceptsPublicKeys.name: true};

    // set twinKeys (late variable, thus important it gets set here)
    twinKeys =
        (pingResponse!['supportedFeatures']?[DaemonFeature.twinKeys.name] ==
        true);
    return featuresToCheck
        .map(
          (featureToCheck) => (
            featureToCheck,
            daemonFeatures[featureToCheck.name] == true,
            daemonFeatures[featureToCheck.name] == true
                ? ''
                : 'This device daemon does not ${featureToCheck.description}',
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> ping() async {
    Completer<Map<String, dynamic>> completer = Completer();

    final String heartbeatKey = 'heartbeat.${params.device}'
        '.${DefaultArgs.namespace}${params.sshnpdAtSign.toAtsign()}';
    late final StreamSubscription<AtNotification> subscription;
    subscription = track(
      subscribe(
        regex: '${RegExp.escape(heartbeatKey)}\$',
        shouldDecrypt: true,
      ).listen((notification) {
        logger.info(
          'Received ping response from ${notification.from} : ${notification.key} : ${notification.value}',
        );
        if (notification.from.toAtsign() == params.sshnpdAtSign.toAtsign()) {
          if (!completer.isCompleted) {
            logger.info('Completing the future');
            completer.complete(jsonDecode(notification.value ?? '{}'));
            unawaited(subscription.cancel());
          }
        }
      }),
    );
    var pingKey = AtKey()
      ..key = "ping.${params.device}"
      ..sharedBy = params.clientAtSign
      ..sharedWith = params.sshnpdAtSign
      ..namespace = DefaultArgs.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true);

    logger.info('Sending ping to sshnpd');
    await notify(
      pingKey,
      'ping',
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    return completer.future;
  }

  /// List all available devices from the daemon.
  /// Returns a [SSHPNPDeviceList] object which contains a map of device names
  /// and corresponding info, and a list of active devices (devices which also
  /// responded to our real-time ping).
  Future<SshnpDeviceList> listDevices({
    Duration waitDuration = Sshnp.defaultListDevicesWaitTime,
  }) async {
    String sharedBy = params.sshnpdAtSign;

    if (sharedBy.isNotEmpty) {
      // if -t was specified fullDeviceName is redundant
      return _listDevices(
        sharedBy,
        useFullDeviceName: false,
        waitDuration: waitDuration,
      );
    }

    // Shared by is empty so first we will lookup all potential device atsigns to list from
    // Then we will _listDevices for each one
    var scanRegex =
        'device_info\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}';
    List<AtKey> atKeys = await getAtKeysRemote(regex: scanRegex);
    Set<String> atSigns = <String>{};

    for (var key in atKeys) {
      if (key.sharedBy != null) atSigns.add(key.sharedBy!);
    }

    // We have to do it this way, or for some reason we get cached keys which...
    List<SshnpDeviceList> deviceLists = await Future.wait(
      atSigns.map((a) => _listDevices(a, waitDuration: waitDuration)).toList(),
    );

    // consolidate the list
    SshnpDeviceList consolidatedList = SshnpDeviceList();
    for (var list in deviceLists) {
      consolidatedList.add(list);
    }

    return consolidatedList;
  }

  Future<SshnpDeviceList> _listDevices(
    String sharedBy, {
    bool useFullDeviceName = true,
    Duration waitDuration = Sshnp.defaultListDevicesWaitTime,
  }) async {
    SshnpDeviceList deviceList = SshnpDeviceList();
    // get all the keys device_info.*.sshnpd
    var scanRegex =
        'device_info\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}';
    List<AtKey> atKeys = await getAtKeysRemote(
      regex: scanRegex,
      sharedBy: sharedBy,
    );

    // Listen for heartbeat notifications
    subscribe(
      regex:
          'heartbeat\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}$sharedBy\$',
      shouldDecrypt: true,
    ).listen((notification) {
      final String? devicename;
      try {
        devicename = jsonDecode(notification.value ?? '{}')['devicename'];
      } catch (e) {
        logger.warning(
          'Ignoring heartbeat ${notification.key} from ${notification.from}: $e',
        );
        return;
      }
      if (devicename == null) {
        logger.warning(
          'Ignoring heartbeat ${notification.key} from ${notification.from}'
          ' with no devicename',
        );
        return;
      }
      deviceList.setActive(
        useFullDeviceName ? devicename + sharedBy : devicename,
      );
    });

    // for each key, get the value
    for (var entryKey in atKeys) {
      bool shouldContinue = false;
      var atValue = await atClient
          .get(
            entryKey,
            getRequestOptions: GetRequestOptions()
              ..bypassCache = true
              ..useRemoteAtServer = true,
          )
          .catchError((_) {
            // Probably a cached key which should have been deleted
            shouldContinue = true;
            return AtValue();
          });

      if (shouldContinue) {
        continue;
      }

      var deviceInfo = jsonDecode(atValue.value) ?? <String, dynamic>{};

      if (deviceInfo['devicename'] == null) {
        continue;
      }

      String devicename = deviceInfo['devicename'];
      String fullDeviceName = devicename + sharedBy;
      deviceList.info[useFullDeviceName ? fullDeviceName : devicename] =
          deviceInfo;

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = false;

      var pingKey = AtKey()
        ..key = "ping.$devicename"
        ..sharedBy = params.clientAtSign
        ..sharedWith = entryKey.sharedBy
        ..namespace = DefaultArgs.namespace
        ..metadata = metaData;

      logger.info('Sending ping to sshnpd');
      unawaited(
        notify(
          pingKey,
          'ping',
          checkForFinalDeliveryStatus: false,
          waitForFinalDeliveryStatus: false,
          ttln: Duration(minutes: 1),
        ),
      );
    }

    // wait for some duration in case any are being slow
    await Future.delayed(waitDuration);

    return deviceList;
  }

  /// A custom implementation of AtClient.getAtKeys which bypasses the cache
  @visibleForTesting
  Future<List<AtKey>> getAtKeysRemote({
    String? regex,
    String? sharedBy,
    String? sharedWith,
    bool showHiddenKeys = false,
  }) async {
    var builder = ScanVerbBuilder()
      ..sharedWith = sharedWith
      ..sharedBy =
          sharedBy // for some reason, if this is null it only returns cached keys
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
            'Exception occurred: ${e.toString()}. Unable to form key $key',
          );
        }
      }).toList();
    }
    result.removeWhere((element) => element == null);
    return result.cast<AtKey>();
  }
}
