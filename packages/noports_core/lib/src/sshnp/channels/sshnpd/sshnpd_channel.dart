import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/async_initialization.dart';
import 'package:noports_core/src/common/at_client_bindings.dart';
import 'package:noports_core/src/sshnp/sshnp_device_list.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/utils.dart';

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
  final logger = AtSignLogger('SSHNPDChannel');
  @override
  final AtClient atClient;

  final SshnpParams params;
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
  });

  /// Initialization starts the subscription to notifications from the daemon.
  @override
  Future<void> initialize() async {
    final namespace = atClient.getPreferences()!.namespace;
    atClient.notificationService
        .subscribe(
          regex: '$sessionId.$namespace@${params.sshnpdAtSign}',
          shouldDecrypt: true,
        )
        .listen(_handleSshnpdResponses);
    completeInitialization();
  }

  /// Main reponse handler for the daemon's notifications.
  Future<void> _handleSshnpdResponses(AtNotification notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$namespace${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');

    bool connected = await handleSshnpdPayload(notification);

    if (connected) {
      logger.info('Session $sessionId connected successfully');
      sshnpdAck = SshnpdAck.acknowledged;
    } else {
      sshnpdAck = SshnpdAck.acknowledgedWithErrors;
    }
  }

  /// This method is responsible for handling and validating the payload
  /// received from the daemon and setting the [ephemeralPrivateKey] field.
  /// Returns true if the daemon is connected, false otherwise.
  @protected
  Future<bool> handleSshnpdPayload(AtNotification notification);

  /// Wait until we've received an acknowledgement from the daemon.
  /// Returns true if the deamon acknowledged our request.
  /// Returns false if a timeout occurred.
  Future<bool> waitForDaemonResponse() async {
    logger.finer('Waiting for daemon response');
    int counter = 0;
    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    while (sshnpdAck == SshnpdAck.notAcknowledged) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        return false;
      }
    }
    return true;
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

    logger.info('Sharing public key with sshnpd');
    try {
      logger.info('sharing ssh public key: $publicKeyContents');
      if (!publicKeyContents.startsWith('ssh-')) {
        logger.severe('SSH Public Key does not look like a public key file');
        throw ('SSH Public Key does not look like a public key file');
      }
      AtKey sendOurPublicKeyToSshnpd = AtKey()
        ..key = 'sshpublickey'
        ..sharedBy = params.clientAtSign
        ..sharedWith = params.sshnpdAtSign
        ..metadata = (Metadata()..ttl = 10000);
      await notify(sendOurPublicKeyToSshnpd, publicKeyContents);
    } catch (e, s) {
      throw SshnpError(
        'Error opening or validating public key file or sending to remote atSign',
        error: e,
        stackTrace: s,
      );
    }
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

    try {
      return (await atClient.get(userNameRecordID).catchError(
        (_) {
          throw SshnpError('Remote username record not shared with the client');
        },
      ))
          .value;
    } catch (e) {
      logger.info(e.toString());
      return null;
    }
  }

  /// List all available devices from the daemon.
  /// Returns a [SSHPNPDeviceList] object which contains a map of device names
  /// and corresponding info, and a list of active devices (devices which also
  /// responded to our real-time ping).
  Future<SshnpDeviceList> listDevices() async {
    // get all the keys device_info.*.sshnpd
    var scanRegex =
        'device_info\\.$sshnpDeviceNameRegex\\.${DefaultArgs.namespace}';

    var atKeys =
        await _getAtKeysRemote(regex: scanRegex, sharedBy: params.sshnpdAtSign);

    SshnpDeviceList deviceList = SshnpDeviceList();

    // Listen for heartbeat notifications
    atClient.notificationService
        .subscribe(
            regex: 'heartbeat\\.$sshnpDeviceNameRegex', shouldDecrypt: true)
        .listen((notification) {
      var deviceInfo = jsonDecode(notification.value ?? '{}');
      var devicename = deviceInfo['devicename'];
      if (devicename != null) {
        deviceList.setActive(devicename);
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
      deviceList.info[devicename] = deviceInfo;

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

      unawaited(notify(pingKey, 'ping'));
    }

    // wait for 10 seconds in case any are being slow
    await Future.delayed(const Duration(seconds: 10));

    return deviceList;
  }

  /// A custom implementation of AtClient.getAtKeys which bypasses the cache
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
}
