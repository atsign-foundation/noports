import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
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
  final logger = AtSignLogger(' SshnpdChannel ');
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

  /// Main reponse handler for the daemon's notifications.
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

  /// Wait until we've received an acknowledgement from the daemon.
  /// Returns true if the deamon acknowledged our request.
  /// Returns false if a timeout occurred.
  Future<SshnpdAck> waitForDaemonResponse() async {
    int counter = 0;
    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    for (int i = 0; i < 100; i++) {
      if ((counter + 1) % 20 == 0) {
        logger.info('Waiting for sshnpd response: $counter');
        logger.info('sshnpdAck: $sshnpdAck');
      }
      await Future.delayed(Duration(milliseconds: 100));
      if (sshnpdAck != SshnpdAck.notAcknowledged) break;
    }
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

  /// Resolve the username to use in the initial ssh tunnel
  /// If [params.tunnelUsername] is set, it will be used.
  /// Otherwise, the username will be set to [remoteUsername]
  Future<String?> resolveTunnelUsername(
      {required String? remoteUsername}) async {
    if (params.tunnelUsername != null) {
      return params.tunnelUsername!;
    } else {
      return remoteUsername;
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
        await getAtKeysRemote(regex: scanRegex, sharedBy: params.sshnpdAtSign);

    SshnpDeviceList deviceList = SshnpDeviceList();

    // Listen for heartbeat notifications
    subscribe(regex: 'heartbeat\\.$sshnpDeviceNameRegex', shouldDecrypt: true)
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

      logger.info('Sending ping to sshnpd');
      unawaited(notify(pingKey, 'ping'));
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
