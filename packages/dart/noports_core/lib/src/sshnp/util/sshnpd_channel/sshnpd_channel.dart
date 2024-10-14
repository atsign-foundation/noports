import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_policy/at_policy.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

import '../../../common/features.dart';

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
abstract class SshnpdChannel with AsyncInitialization, AtClientBindings {
  @override
  final logger = AtSignLogger(' SshnpdChannel ');
  @override
  final AtClient atClient;

  final SshnpdChannelParams params;
  final String sessionId;
  final String namespace;

  // * Volatile fields set at runtime

  /// State of sshnpd acknowledgement
  @visibleForTesting
  @protected
  SshnpdAck sshnpdAck = SshnpdAck.notAcknowledged;

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
    String regex = '$sessionId.$namespace${params.sshnpdAtSign}';
    logger.info('Starting monitor for notifications with regex: "$regex"');
    subscribe(
      regex: regex,
      shouldDecrypt: true,
    ).listen(handleSshnpdResponses);
  }

  /// Main response handler for the daemon's notifications.
  @visibleForTesting
  Future<void> handleSshnpdResponses(AtNotification notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$namespace@${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');

    sshnpdAck = await handleSshnpdPayload(notification);

    if (sshnpdAck == SshnpdAck.acknowledged) {
      logger.info('Session $sessionId connected successfully');
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
    // TODO Would maybe be better to return a Future<SshnpdAck, String>
    //      with the String being the failure reason (if any)

    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    for (int counter = 1; counter <= 100; counter++) {
      if (counter % 20 == 0) {
        logger.info('Still waiting for sshnpd response');
      }
      await Future.delayed(Duration(milliseconds: maxWaitMillis ~/ 100));
      if (sshnpdAck != SshnpdAck.notAcknowledged) break;
    }
    logger.info('sshnpdAck: $sshnpdAck');
    return sshnpdAck;
  }

  /// Send a notification to the daemon with our shared public key.
  /// Does nothing if [params.sendSshPublicKey] is false or if [identityKeyPair]
  /// is null.
  Future<void> sharePublicKeyIfRequired(AtSshKeyPair? identityKeyPair) async {
    if (!params.sendSshPublicKey) {
      logger.info(
          'Skipped sharing public key with sshnpd: sendSshPublicKey=false');
      return;
    }
    if (identityKeyPair == null) {
      logger.info(
          'Skipped sharing public key with sshnpd: no identity key pair set');
      return;
    }

    var publicKeyContents = identityKeyPair.publicKeyContents;

    logger.info('Sharing ssh public key with sshnpd: $publicKeyContents');
    // Check for Supported ssh keypairs from dartssh2 package
    if (!publicKeyContents.startsWith(RegExp(
        r'^(ecdsa-sha2-nistp)|(rsa-sha2-)|(ssh-rsa)|(ssh-ed25519)|(ecdsa-sha2-nistp)'))) {
      throw SshnpError('SSH Public Key does not look like a public key file');
    }
    AtKey sendOurPublicKeyToSshnpd = AtKey()
      ..key = 'sshpublickey'
      ..sharedBy = params.clientAtSign
      ..sharedWith = params.sshnpdAtSign
      ..metadata = (Metadata()..ttl = 10000);
    unawaited(notify(
      sendOurPublicKeyToSshnpd,
      publicKeyContents,
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    ).onError((e, st) {
      throw SshnpError('Error sending ssh public key to sshnpd: $e');
    }));
  }

  /// Resolve the remote username to use in the ssh session.
  /// If [params.remoteUsername] is set, it will be used.
  /// Otherwise, the username will be fetched from the remote atSign.
  /// Returns null if the username could not be resolved.
  Future<String?> resolveRemoteUsername() async {
    if (params.remoteUsername != null) {
      return params.remoteUsername!;
    }
    AtKey userNameRecordID = AtKey.fromString(
        '${params.clientAtSign}:username.$namespace${params.sshnpdAtSign}');

    return (await atClient.get(userNameRecordID).catchError(
      (_) {
        throw SshnpError('Remote username record not shared with the client');
      },
    ))
        .value;
  }

  /// Resolve the username to use in the initial ssh tunnel
  /// If [params.tunnelUsername] is set, it will be used.
  /// Otherwise, the username will be set to [remoteUsername]
  Future<String?> resolveTunnelUsername(
      {required String? remoteUsername}) async {
    if (params.tunnelUsername != null &&
        params.tunnelUsername!.trim().isNotEmpty) {
      return params.tunnelUsername!;
    } else {
      return remoteUsername;
    }
  }

  Future<List<(DaemonFeature feature, bool supported, String reason)>>
      featureCheck(
    List<DaemonFeature> featuresToCheck,
    List<PolicyIntent> intents, {
    Duration timeout = DefaultArgs.daemonPingTimeoutDuration,
  }) async {
    if (featuresToCheck.isEmpty) {
      return [];
    }
    Map<String, dynamic> pingResponse;
    try {
      pingResponse = await ping().timeout(timeout);
    } on TimeoutException catch (_) {
      throw TimeoutException('Daemon feature check timed out');
    }

    // If supportedFeatures was null (i.e. a response from a v4 daemon),
    // then we will assume that "acceptsPublicKeys" is true
    final Map<String, dynamic> daemonFeatures =
        pingResponse['supportedFeatures'] ??
            {DaemonFeature.acceptsPublicKeys.name: true};
    return featuresToCheck
        .map((featureToCheck) => (
              featureToCheck,
              daemonFeatures[featureToCheck.name] == true,
              daemonFeatures[featureToCheck.name] == true
                  ? ''
                  : 'This device daemon does not ${featureToCheck.description}',
            ))
        .toList();
  }

  Future<Map<String, dynamic>> ping() async {
    Completer<Map<String, dynamic>> completer = Completer();

    subscribe(
      regex: 'heartbeat'
          '.${params.device}'
          '.${DefaultArgs.namespace}',
      shouldDecrypt: true,
    ).listen((notification) {
      logger.info(
          'Received ping response from ${notification.from} : ${notification.key} : ${notification.value}');
      if (notification.from == params.sshnpdAtSign) {
        if (!completer.isCompleted) {
          logger.info('Completing the future');
          completer.complete(jsonDecode(notification.value ?? '{}'));
        }
      }
    });
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
  Future<SshnpDeviceList> listDevices() async {
    String sharedBy = params.sshnpdAtSign;

    if (sharedBy.isNotEmpty) {
      return _listDevices(sharedBy,
          useFullDeviceName:
              false); // if -t was specified fullDeviceName is redundant
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
    List<SshnpDeviceList> deviceLists =
        await Future.wait(atSigns.map((a) => _listDevices(a)).toList());

    // consolidate the list
    SshnpDeviceList consolidatedList = SshnpDeviceList();
    for (var list in deviceLists) {
      consolidatedList.add(list);
    }

    return consolidatedList;
  }

  Future<SshnpDeviceList> _listDevices(String sharedBy,
      {bool useFullDeviceName = true}) async {
    SshnpDeviceList deviceList = SshnpDeviceList();
    // get all the keys device_info.*.sshnpd
    var scanRegex =
        'device_info\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}';
    List<AtKey> atKeys =
        await getAtKeysRemote(regex: scanRegex, sharedBy: sharedBy);

    // Listen for heartbeat notifications
    subscribe(regex: 'heartbeat\\.$sshnpDeviceNameRegex', shouldDecrypt: true)
        .listen((notification) {
      var deviceInfo = jsonDecode(notification.value ?? '{}');
      var devicename = deviceInfo['devicename'];
      var fullDeviceName = devicename + sharedBy;
      if (devicename != null) {
        deviceList.setActive(useFullDeviceName ? fullDeviceName : devicename);
      }
    });

    // for each key, get the value
    for (var entryKey in atKeys) {
      bool shouldContinue = false;
      var atValue = await atClient
          .get(
        entryKey,
        getRequestOptions: GetRequestOptions()..bypassCache = true,
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
        ..namespaceAware = true;

      var pingKey = AtKey()
        ..key = "ping.$devicename"
        ..sharedBy = params.clientAtSign
        ..sharedWith = entryKey.sharedBy
        ..namespace = DefaultArgs.namespace
        ..metadata = metaData;

      logger.info('Sending ping to sshnpd');
      unawaited(notify(
        pingKey,
        'ping',
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
        ttln: Duration(minutes: 1),
      ));
    }

    // wait for 10 seconds in case any are being slow
    await Future.delayed(const Duration(seconds: 10));

    return deviceList;
  }

  /// A custom implementation of AtClient.getAtKeys which bypasses the cache
  @visibleForTesting
  Future<List<AtKey>> getAtKeysRemote(
      {String? regex,
      String? sharedBy,
      String? sharedWith,
      bool showHiddenKeys = false}) async {
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
              'Exception occurred: ${e.toString()}. Unable to form key $key');
        }
      }).toList();
    }
    result.removeWhere((element) => element == null);
    return result.cast<AtKey>();
  }
}
