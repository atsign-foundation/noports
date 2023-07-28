import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/supported_ssh_clients.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';
import 'package:sshnoports/sshnpd/sshnpd_params.dart';
import 'package:sshnoports/version.dart';
import 'package:uuid/uuid.dart';

class SSHNPDImpl implements SSHNPD {
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
  late final String managerAtsign;

  @override
  final SupportedSshClient sshClient;

  @override
  @visibleForTesting
  bool initialized = false;

  /// State variables used by [_notificationHandler]
  String _privateKey = "";

  static const String commandToSend = 'sshd';

  SSHNPDImpl(
      {
      // final fields
      required this.atClient,
      required this.username,
      required this.homeDirectory,
      required this.device,
      required this.managerAtsign,
      required this.sshClient}) {
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
  }

  static Future<SSHNPD> fromCommandLineArgs(List<String> args) async {
    try {
      var p = SSHNPDParams.fromArgs(args);

      // Check atKeyFile selected exists
      if (!await fileExists(p.atKeysFilePath)) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClientCli(
        homeDirectory: p.homeDirectory,
        atsign: p.deviceAtsign,
        atKeysFilePath: p.atKeysFilePath,
      );

      var sshnpd = SSHNPD(
          atClient: atClient,
          username: p.username,
          homeDirectory: p.homeDirectory,
          device: p.device,
          managerAtsign: p.managerAtsign,
          sshClient: p.sshClient);

      if (p.verbose) {
        sshnpd.logger.logger.level = Level.INFO;
      }

      return sshnpd;
    } catch (e) {
      printVersion();
      stdout.writeln(SSHNPDParams.parser.usage);
      stderr.writeln('\n$e');
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

    if (username != '') {
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..ttr = -1
        ..namespaceAware = true;

      var atKey = AtKey()
        ..key = "username.$device"
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = SSHNPD.namespace
        ..metadata = metaData;

      try {
        await notificationService.notify(
            NotificationParams.forUpdate(atKey, value: username),
            waitForFinalDeliveryStatus: false,
            checkForFinalDeliveryStatus: false, onSuccess: (notification) {
          logger.info('SUCCESS:$notification $username');
        }, onError: (notification) {
          logger.info('ERROR:$notification $username');
        });
      } catch (e) {
        stderr.writeln(e.toString());
      }
    }

    logger.info('Starting connectivity listener');
    // Keep an eye on connectivity and report failures if we see them
    ConnectivityListener().subscribe().listen((isConnected) {
      if (isConnected) {
        logger.warning('connection available');
      } else {
        logger.warning('connection lost');
      }
    });

    logger.info('Subscribing to $device\\.${SSHNPD.namespace}@');
    notificationService
        .subscribe(regex: '$device\\.${SSHNPD.namespace}@', shouldDecrypt: true)
        .listen(
          _notificationHandler,
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'),
        );

    // Refresh the device entry now, and every hour
    await _refreshDeviceEntry();
    Timer.periodic(
      const Duration(hours: 1),
      (_) async => await _refreshDeviceEntry(),
    );

    logger.info('Done');
  }

  /// Notification handler for sshnpd
  void _notificationHandler(AtNotification notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.${SSHNPD.namespace}${notification.from}', '')
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
        late final String sshPublicKey;
        try {
          var sshHomeDirectory = "$homeDirectory/.ssh/";
          if (Platform.isWindows) {
            sshHomeDirectory = '$homeDirectory\\.ssh\\';
          }
          logger.info(
              'ssh Public Key received from ${notification.from} notification id : ${notification.id}');
          sshPublicKey = notification.value!;

          // Check to see if the ssh public key looks like one!
          if (!sshPublicKey.startsWith('ssh-')) {
            throw ('$sshPublicKey does not look like a public key');
          }

          // Check to see if the ssh Publickey is already in the file if not append to the ~/.ssh/authorized_keys file
          var authKeys = File('${sshHomeDirectory}authorized_keys');

          var authKeysContent = await authKeys.readAsString();

          if (!authKeysContent.contains(sshPublicKey)) {
            authKeys.writeAsStringSync("\n$sshPublicKey",
                mode: FileMode.append);
          }
        } catch (e) {
          logger.severe(
              'Error writing to $username .ssh/authorized_keys file : $e');
        }
        break;
      case 'sshd':
        logger.info(
            'ssh callback request received from ${notification.from} notification id : ${notification.id}');
        _sshCallback(notification, _privateKey, logger, managerAtsign,
            deviceAtsign, device);
        break;
      case 'ping':
        logger.info(
            'ping received from ${notification.from} notification id : ${notification.id}');
        var metaData = Metadata()
          ..isPublic = false
          ..isEncrypted = true
          ..ttr = -1
          ..namespaceAware = true;

        var atKey = AtKey()
          ..key = "heartbeat.$device"
          ..sharedBy = deviceAtsign
          ..sharedWith = managerAtsign
          ..namespace = SSHNPD.namespace
          ..metadata = metaData;

        /// send a heartbeat back
        await _notify(
          atKey,
          {
            'devicename': device,
            'version': version,
          }.toString(),
        );
        break;
    }
  }

  /// A callback which is called to start an sshnp session
  void _sshCallback(
      AtNotification notification,
      String privateKey,
      AtSignLogger logger,
      String managerAtsign,
      String deviceAtsign,
      String device) async {
    // sessionId is local if we do not have a 2.0 client
    var uuid = Uuid();
    String sessionId = uuid.v4();
    String sshString = notification.value!;

    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..namespaceAware = true
      ..ttr = -1
      ..ttl = 10000;

    /// Setup an atKey to return a notification to the managerAtsign
    var atKey = AtKey()
      ..key = '$sessionId.$device'
      ..sharedBy = deviceAtsign
      ..sharedWith = managerAtsign
      ..namespace = SSHNPD.namespace
      ..metadata = metaData;

    if (notification.from != managerAtsign) {
      logger.shout(
          'ssh session attempted from: ${notification.from} session: $sessionId and ignored');
      return;
    }

    /// Local port, port of sshd, username, hostname
    List<String> sshList = sshString.split(' ');
    var localPort = sshList[0];
    var port = sshList[1];
    var username = sshList[2];
    var hostname = sshList[3];

    /// Assure backward compatibility with 1.x clients
    if (sshList.length == 5) {
      sessionId = sshList[4];
      atKey = AtKey()
        ..key = '$sessionId.$device'
        ..sharedBy = deviceAtsign
        ..sharedWith = managerAtsign
        ..namespace = SSHNPD.namespace
        ..metadata = metaData;
    }

    logger.info(
        'Starting ssh session for $username to $hostname on port $port using localhost:$localPort on $hostname ');
    logger.shout(
        'Starting ssh session using ${sshClient.name} (${sshClient.cliArg}) from: ${notification.from} session: $sessionId');

    try {
      bool success = false;
      String? errorMessage;

      switch (sshClient) {
        case SupportedSshClient.hostSsh:
          (success, errorMessage) = await reverseSshViaExec(privateKey,
              username, hostname, port, localPort, logger, sessionId);
          break;
        case SupportedSshClient.pureDart:
          (success, errorMessage) = await reverseSshViaSSHClient(privateKey,
              username, hostname, port, localPort, logger, sessionId);
          break;
      }

      if (!success) {
        errorMessage ??= 'Failed to forward remote port $localPort';
        logger.warning(errorMessage);
        // Notify sshnp that this session is NOT connected
        await _notify(
          atKey,
          '$errorMessage (use --local-port to specify unused port)',
          sessionId: sessionId,
        );
      } else {
        /// Notify sshnp that the connection has been made
        logger.info(' sshnpd connected notification sent to:from "$atKey');
        await _notify(atKey, "connected", sessionId: sessionId);
      }
    } catch (e) {
      logger.severe('SSH Client failure : $e');
      // Notify sshnp that this session is NOT connected
      await _notify(
        atKey,
        'Remote SSH Client failure : $e',
        sessionId: sessionId,
      );
    }
  }

  /// Reverse ssh using SSHClient.
  /// We will ssh outwards with a remote port forwarding to allow a client on
  /// the other side to ssh to port 22 here.
  Future<(bool, String?)> reverseSshViaSSHClient(
      String privateKey,
      String username,
      String hostname,
      String port,
      String localPort,
      AtSignLogger logger,
      String sessionId) async {
    late final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(hostname, int.parse(port));
    } catch (e) {
      return (false, 'Failed to open socket to $hostname:$port : $e');
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
        'Failed to create SSHClient for $username@$hostname:$port : $e'
      );
    }

    try {
      await client.authenticated;
    } catch (e) {
      return (
        false,
        'Failed to authenticate as $username@$hostname:$port : $e'
      );
    }

    /// Do the port forwarding
    final SSHRemoteForward? forward;
    try {
      forward = await client.forwardRemote(port: int.parse(localPort));
    } catch (e) {
      return (false, 'Failed to request forwardRemote : $e');
    }

    if (forward == null) {
      return (false, 'Failed to forward remote port $localPort');
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
        final socket = await Socket.connect('localhost', 22);

        unawaited(
          connection.stream.cast<List<int>>().pipe(socket).whenComplete(
            () async {
              counter--;
            },
          ),
        );
        unawaited(socket.pipe(connection.sink));
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
  /// the other side to ssh to port 22 here.
  Future<(bool, String?)> reverseSshViaExec(
      String privateKey,
      String username,
      String hostname,
      String port,
      String localPort,
      AtSignLogger logger,
      String sessionId) async {
    final pemFile = File('/tmp/.${Uuid().v4()}');
    if (!privateKey.endsWith('\n')) {
      privateKey += '\n';
    }
    pemFile.writeAsStringSync(privateKey);
    await Process.run('chmod', ['go-rwx', pemFile.absolute.path]);

    // When we receive notification 'sshd', WE are going to ssh to the host and port provided by sshnp
    // which could be the host and port of a client machine, or the host and port of an sshrvd which is
    // joined via socket connector to the client machine. Let's call it targetHostName/Port
    //
    // so: ssh username@targetHostName -p targetHostPort
    //
    // We need to use the private key which the client sent to us (and we just stored in a tmp file)
    // This is done by adding '-i <pemFile>' to the ssh command
    //
    // When we make the connection (remember we are the client) we want to tell the client
    // to listen on some port and forward all connections to that port to port 22 on sshnpd's host.
    // The incantation for that is -R clientHostPort:localhost:22
    //
    // We will disable strict host checking since we don't know what hosts we're going to be
    // connecting to. Instead, we'll accept new hostnames but the checks will still be executed
    // if the host identity has changed.
    // -o StrictHostKeyChecking=accept-new
    //
    // We don't want keyboard interactive: we add -o BatchMode=yes
    //
    // For convenience of this SSHNPD, we would like to know as quickly
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
    //
    // Final command will look like this:
    //
    // ssh username@targetHostName -p targetHostPort -i $pemFile -R clientForwardPort:localhost:22 \
    //     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    //     sleep 15
    List<String> args = '$username@$hostname'
            ' -p $port'
            ' -i ${pemFile.absolute.path}'
            ' -R $localPort:localhost:22'
            ' -o LogLevel=VERBOSE'
            ' -t -t'
            ' -o StrictHostKeyChecking=accept-new'
            ' -o IdentitiesOnly=yes'
            ' -o BatchMode=yes'
            ' -o ExitOnForwardFailure=yes'
            ' -o ForkAfterAuthentication=yes'
            ' sleep 15'
        .split(' ');
    logger.info('$sessionId | Executing /usr/bin/ssh ${args.join(' ')}');

    // Because of the options we are using, we can wait for this process
    // to complete, because it will exit with exitCode 0 once it has connected
    // successfully
    late int sshExitCode;
    final soutBuf = StringBuffer();
    final serrBuf = StringBuffer();
    try {
      Process process = await Process.start('/usr/bin/ssh', args);
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
            '$sessionId | Command timed out: /usr/bin/ssh ${args.join(' ')}');
        errorMessage = 'Failed to establish connection - timed out';
      } else {
        logger.shout('$sessionId | Exit code $sshExitCode from'
            ' /usr/bin/ssh ${args.join(' ')}');
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
  Future<void> _notify(AtKey atKey, String value,
      {String sessionId = ""}) async {
    await atClient.notificationService
        .notify(NotificationParams.forUpdate(atKey, value: value),
            onSuccess: (notification) {
      logger.info('SUCCESS:$notification for: $sessionId with value: $value');
    }, onError: (notification) {
      logger.info('ERROR:$notification');
    });
  }

  /// This function creates an atKey which shares the device name with the client
  Future<void> _refreshDeviceEntry() async {
    const ttl = 1000 * 60 * 60 * 24 * 30; // 30 days
    var metaData = Metadata()
      ..isPublic = false
      ..isEncrypted = true
      ..ttr = -1
      ..ttl = ttl
      ..updatedAt = DateTime.now()
      ..namespaceAware = true;

    var atKey = AtKey()
      ..key = "devicename.$device"
      ..sharedBy = deviceAtsign
      ..sharedWith = managerAtsign
      ..namespace = SSHNPD.namespace
      ..metadata = metaData;

    try {
      logger.info('Updating device name for $device');
      await atClient.put(
        atKey,
        {
          'devicename': device,
          'version': version,
        }.toString(),
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );
    } catch (e) {
      stderr.writeln(e.toString());
    }
  }
}
