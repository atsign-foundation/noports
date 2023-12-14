import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshrvd/signature_verifying_socket_authenticator.dart';
import 'package:noports_core/src/sshrvd/socket_connector.dart';
import 'package:noports_core/src/sshrvd/sshrvd.dart';
import 'package:noports_core/src/sshrvd/sshrvd_params.dart';
import 'package:socket_connector/socket_connector.dart';

@protected
class SshrvdImpl implements Sshrvd {
  @override
  final AtSignLogger logger = AtSignLogger(' sshrvd ');
  @override
  AtClient atClient;
  @override
  final String atSign;
  @override
  final String homeDirectory;
  @override
  final String atKeysFilePath;
  @override
  final String managerAtsign;
  @override
  final String ipAddress;
  @override
  final bool snoop;

  @override
  @visibleForTesting
  bool initialized = false;

  static final String subscriptionRegex = '${Sshrvd.namespace}@';

  SshrvdImpl({
    required this.atClient,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.snoop,
  }) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<Sshrvd> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SshrvdParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    try {
      var p = await SshrvdParams.fromArgs(args);

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

      var sshrvd = SshrvdImpl(
        atClient: atClient,
        atSign: p.atSign,
        homeDirectory: p.homeDirectory,
        atKeysFilePath: p.atKeysFilePath,
        managerAtsign: p.managerAtsign,
        ipAddress: p.ipAddress,
        snoop: p.snoop,
      );

      if (p.verbose) {
        sshrvd.logger.logger.level = Level.INFO;
      }
      return sshrvd;
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
    NotificationService notificationService = atClient.notificationService;

    notificationService
        .subscribe(regex: subscriptionRegex, shouldDecrypt: true)
        .listen(_notificationHandler);
  }

  void _notificationHandler(AtNotification notification) async {
    if (!SshrvdUtil.accept(notification)) {
      return;
    }
    late String session;
    late String atSignA;
    String? atSignB;
    SocketAuthenticator? socketAuthenticatorA;
    SocketAuthenticator? socketAuthenticatorB;

    try {
      (session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB) = await SshrvdUtil.getParams(notification);

      if (managerAtsign != 'open' && managerAtsign != atSignA) {
        logger.shout('Session $session for $atSignA is denied');
        return;
      }

    }catch(e) {
      logger.shout(
          'Unable to provide the socket pair due to: $e');
      return;
    }
    (int, int) ports =
        await _spawnSocketConnector(0, 0, session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB, snoop);
    var (portA, portB) = ports;
    logger
        .warning('Starting session $session for $atSignA to $atSignB using ports $ports');

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttl = 10000
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = session
      ..sharedBy = atSign
      ..sharedWith = notification.from
      ..namespace = Sshrvd.namespace
      ..metadata = metaData;

    String data = '$ipAddress,$portA,$portB';

    try {
      await atClient.notificationService.notify(
          NotificationParams.forUpdate(atKey, value: data),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false);
    } catch (e) {
      stderr.writeln("Error writting session ${notification.value} atKey");
    }
  }

  /// This function spawns a new socketConnector in a background isolate
  /// once the socketConnector has spawned and is ready to accept connections
  /// it sends back the port numbers to the main isolate
  /// then the port numbers are returned from this function
  Future<PortPair> _spawnSocketConnector(
    int portA,
    int portB,
    String session,
    String atSignA,
    String? atSignB, SocketAuthenticator? socketAuthenticatorA,
      SocketAuthenticator? socketAuthenticatorB,
    bool snoop,
  ) async {
    /// Spawn an isolate and wait for it to send back the issued port numbers
    ReceivePort receivePort = ReceivePort(session);

    ConnectorParams parameters =
        (receivePort.sendPort, portA, portB, session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB, snoop);

    logger
        .info("Spawning socket connector isolate with parameters $parameters");

    unawaited(Isolate.spawn<ConnectorParams>(socketConnector, parameters));

    PortPair ports = await receivePort.first;

    logger.info('Received ports $ports in main isolate for session $session');

    return ports;
  }
}

class SshrvdUtil {
  static bool accept(AtNotification notification) {
    return notification.key.contains(Sshrvd.namespace);
  }

  static Future<(String, String, String?, SocketAuthenticator?, SocketAuthenticator?)> getParams(AtNotification notification)  async {
    if(notification.key.contains('request_ports') && notification.key.contains(Sshrvd.namespace)) {
      return await _processJSONRequest(notification);
    }
    return _processLegacyRequest(notification);;
  }


  static (String, String, String?, SocketAuthenticator?, SocketAuthenticator?) _processLegacyRequest(AtNotification notification) {
    return (notification.value!, notification.from, null, null, null);
  }

  static Future<(String, String, String?, SocketAuthenticator?, SocketAuthenticator?)> _processJSONRequest(AtNotification notification) async {
    String session = '';
    String atSignA = '';
    String atSignB = '';
    bool authenticateSocketA = false;
    bool authenticateSocketB = false;
    SocketAuthenticator? socketAuthenticatorA;
    SocketAuthenticator? socketAuthenticatorB;

    dynamic jsonValue = jsonDecode(notification.value ?? '');

    if(jsonValue['session'] == null || jsonValue['atSignA'] == null || jsonValue['atSignB'] == null) {
      throw Exception('session, atSignA and atSignB cannot be empty');
    }

    session = jsonValue['session'];
    atSignA = jsonValue['atSignA'];
    atSignB = jsonValue['atSignB'];
    authenticateSocketA = jsonValue['authenticateSocketA'];
    authenticateSocketB = jsonValue['authenticateSocketB'];

    if(authenticateSocketA) {
      String? pkAtSignA = await _fetchPublicKey(atSignA);
      if(pkAtSignA == null) {
        logger.shout(
            'Cannot spawn socket connector. Authenticator for $atSignA could not be created as PublicKey could not be fetched from the secondary server.');
        throw Exception('Unable to create SocketAuthenticator for $atSignA due to not able to get public key for $atSignA');
      }
      socketAuthenticatorA = SignatureVerifyingSocketAuthenticator(pkAtSignA, session);
    }

    if(authenticateSocketB) {
      String? pkAtSignB = await _fetchPublicKey(atSignB);
      if(pkAtSignB == null) {
        logger.shout(
            'Cannot spawn socket connector. Authenticator for $atSignB could not be created as PublicKey could not be fetched from the secondary server.');
        throw Exception('Unable to create SocketAuthenticator for $atSignB due to not able to get public key for $atSignB');
      }
      socketAuthenticatorB = SignatureVerifyingSocketAuthenticator(pkAtSignB, session);
    }

    return (session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB);
  }

  static Future<String?> _fetchPublicKey(String atSign,
      {int secondsToWait = 10}) async {
    String? publicKey;
    AtLookupImpl atLookupImpl = AtLookupImpl(atSign, 'root.atsign.org', 64);
    SecondaryAddress secondaryAddress =
    await atLookupImpl.secondaryAddressFinder.findSecondary(atSign);

    SecureSocket secureSocket = await SecureSocket.connect(
        secondaryAddress.host, secondaryAddress.port);

    secureSocket.listen((event) {
      String serverResponse = utf8.decode(event);
      if (serverResponse == '@') {
        secureSocket.write('lookup:publickey$atSign\n');
      } else if (serverResponse.startsWith('data:')) {
        publicKey = serverResponse.replaceFirst('data:', '');
        publicKey = publicKey?.substring(0, publicKey?.indexOf('\n')).trim();
      }
    });


    int totalSecondsWaited = 0;
    while (totalSecondsWaited < secondsToWait) {
      await Future.delayed(Duration(seconds: 1));
      totalSecondsWaited = totalSecondsWaited + 1;
      if (publicKey != null) {
        break;
      }
    }
    await secureSocket.close();
    return publicKey;
  }
}
