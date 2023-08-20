import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/common/create_at_client_cli.dart';
import 'package:sshnoports/common/supported_ssh_clients.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/utils.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnoports/sshnp/sshnp_params.dart';
import 'package:sshnoports/sshnpd/sshnpd.dart';
import 'package:sshnoports/sshrvd/sshrvd.dart';
import 'package:sshnoports/version.dart';
import 'package:uuid/uuid.dart';

import 'package:at_commons/at_builders.dart';

class SSHNPImpl implements SSHNP {
  @override
  final AtSignLogger logger = AtSignLogger(' sshnp ');

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The [AtClient] used to communicate with sshnpd and sshrvd
  @override
  final AtClient atClient;

  /// The atSign of the sshnpd we wish to communicate with
  @override
  final String sshnpdAtSign;

  /// The device name of the sshnpd we wish to communicate with
  @override
  final String device;

  /// The user name on this host
  @override
  final String username;

  /// The home directory on this host
  @override
  final String homeDirectory;

  /// The sessionId we will use
  @override
  final String sessionId;

  @override
  late final String publicKeyFileName;

  @override
  final List<String> localSshOptions;

  @override
  late final String localSshdPort;

  /// When false, we generate [sshPublicKey] and [sshPrivateKey] using ed25519.
  /// When true, we generate [sshPublicKey] and [sshPrivateKey] using RSA.
  /// Defaults to false
  @override
  final bool rsa;

  // ====================================================================
  // Volatile instance variables, injected via constructor
  // but possibly modified later on
  // ====================================================================

  /// Host that we will send to sshnpd for it to connect to,
  /// or the atSign of the sshrvd.
  /// If using sshrvd then we will fetch the _actual_ host to use from sshrvd.
  @override
  String host;

  /// Port that we will send to sshnpd for it to connect to.
  /// Required if we are not using sshrvd.
  /// If using sshrvd then initial port value will be ignored and instead we
  /// will fetch the port from sshrvd.
  @override
  String port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  @override
  String localPort;

  // ====================================================================
  // Derived final instance variables, set during construction or init
  // ====================================================================

  /// Set to [AtClient.getCurrentAtSign] during construction
  @override
  @visibleForTesting
  late final String clientAtSign;

  /// The username to use on the remote host in the ssh session. Either passed
  /// through class constructor or fetched from the sshnpd
  /// by [fetchRemoteUserName] during [init]
  @override
  String? remoteUsername;

  /// Set by [generateSshKeys] during [init], if we're not doing direct ssh.
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will write
  /// [sshPublicKey] to ~/.ssh/authorized_keys
  @override
  late final String sshPublicKey;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will send the
  /// [sshPrivateKey] to sshnpd
  @override
  late final String sshPrivateKey;

  /// Namespace will be set to [device].sshnp
  @override
  late final String namespace;

  /// When using sshrvd, this is fetched from sshrvd during [init]
  /// This is only set when using sshrvd
  /// (i.e. after [getHostAndPortFromSshrvd] has been called)
  @override
  String get sshrvdPort => _sshrvdPort;

  late String _sshrvdPort;

  /// Set by constructor to
  /// '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}'
  @override
  late final String sshHomeDirectory;

  /// true once we have received any response (success or error) from sshnpd
  @override
  @visibleForTesting
  bool sshnpdAck = false;

  /// true once we have received an error response from sshnpd
  @override
  @visibleForTesting
  bool sshnpdAckErrors = false;

  /// true once we have received a response from sshrvd
  @override
  @visibleForTesting
  bool sshrvdAck = false;

  /// true once [init] has completed
  @override
  bool initialized = false;

  @override
  bool verbose = false;

  @override
  late final bool legacyDaemon;

  @override
  late final bool direct;

  final SupportedSshClient sshClient = SupportedSshClient.hostSsh;

  SSHNPImpl(
      {
      // final fields
      required this.atClient,
      required this.sshnpdAtSign,
      required this.device,
      required this.username,
      required this.homeDirectory,
      required this.sessionId,
      String sendSshPublicKey = 'false',
      required this.localSshOptions,
      this.rsa = false,
      // volatile fields
      required this.host,
      required this.port,
      required this.localPort,
      this.remoteUsername,
      this.verbose = false,
      required this.legacyDaemon,
      required this.localSshdPort}) {
    namespace = '$device.sshnp';
    clientAtSign = atClient.getCurrentAtSign()!;
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    if (!Directory(sshHomeDirectory).existsSync()) {
      Directory(sshHomeDirectory).createSync();
    }

    if (sendSshPublicKey != 'false') {
      publicKeyFileName = '$sshHomeDirectory$sendSshPublicKey';
    } else {
      publicKeyFileName = 'false';
    }
  }

  static Future<SSHNP> fromCommandLineArgs(List<String> args) {
    var params = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgs(args));
    return fromParams(params);
  }

  static Future<SSHNP> fromParams(SSHNPParams p) async {
    try {
      if (p.clientAtSign == null) {
        throw ArgumentError('Option from is mandatory.');
      }

      if (p.sshnpdAtSign == null) {
        throw ArgumentError('Option to is mandatory.');
      }

      if (p.host == null) {
        throw ArgumentError('Option host is mandatory.');
      }

      // Check atKeyFile selected exists
      if (!await fileExists(p.atKeysFilePath)) {
        throw ('\nUnable to find .atKeys file : ${p.atKeysFilePath}');
      }

      String sessionId = Uuid().v4();

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClientCli(
          homeDirectory: p.homeDirectory,
          atsign: p.clientAtSign!,
          namespace: '${p.device}.sshnp',
          pathExtension: sessionId,
          atKeysFilePath: p.atKeysFilePath,
          rootDomain: p.rootDomain);

      var sshnp = SSHNP(
          atClient: atClient,
          sshnpdAtSign: p.sshnpdAtSign!,
          username: p.username,
          homeDirectory: p.homeDirectory,
          sessionId: sessionId,
          device: p.device,
          host: p.host!,
          port: p.port,
          localPort: p.localPort,
          localSshOptions: p.localSshOptions,
          localSshdPort: p.localSshdPort,
          rsa: p.rsa,
          sendSshPublicKey: p.sendSshPublicKey,
          remoteUsername: p.remoteUsername,
          verbose: p.verbose,
          legacyDaemon: p.legacyDaemon);
      if (p.verbose) {
        sshnp.logger.logger.level = Level.INFO;
      }

      return sshnp;
    } catch (e) {
      printVersion();
      stdout.writeln(SSHNPPartialParams.parser.usage);
      stderr.writeln('\n$e');
      rethrow;
    }
  }

  /// Must be run after construction, to complete initialization
  /// - Starts notification subscription to listen for responses from sshnpd
  /// - calls [generateSshKeys] which generates the ssh keypair to use
  ///   ( [sshPublicKey] and [sshPrivateKey] )
  /// - calls [fetchRemoteUserName] to fetch the username to use on the remote
  ///   host in the ssh session
  /// - If not supplied via constructor, finds a spare port for [localPort]
  /// - If using sshrv, calls [getHostAndPortFromSshrvd] to fetch host and port
  ///   from sshrvd
  /// - calls [sharePrivateKeyWithSshnpd]
  /// - calls [sharePublicKeyWithSshnpdIfRequired]
  @override
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    // determine the ssh direction
    direct = useDirectSsh(legacyDaemon, host);

    if (!(await atSignIsActivated(atClient, sshnpdAtSign))) {
      throw ('sshnpd atSign $sshnpdAtSign is not activated.');
    }

    logger.info('Subscribing to notifications on $sessionId.$namespace@');
    // Start listening for response notifications from sshnpd
    atClient.notificationService
        .subscribe(regex: '$sessionId.$namespace@', shouldDecrypt: true)
        .listen(handleSshnpdResponses);

    if (publicKeyFileName != 'false' && !File(publicKeyFileName).existsSync()) {
      throw ('\n Unable to find ssh public key file : $publicKeyFileName');
    }

    remoteUsername ?? await fetchRemoteUserName();

    // find a spare local port
    if (localPort == '0') {
      ServerSocket serverSocket =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      localPort = serverSocket.port.toString();
      await serverSocket.close();
    }

    await sharePublicKeyWithSshnpdIfRequired();

    // If host has an @ then contact the sshrvd service for some ports
    if (host.startsWith('@')) {
      await getHostAndPortFromSshrvd();
    }

    // If we're doing reverse (i.e. not direct) then we need to
    // 1) generate some ephemeral keys for the daemon to use to ssh back to us
    // 2) if legacy then we share the private key via its own notification
    if (!direct) {
      await generateSshKeys();
      if (legacyDaemon) {
        await sharePrivateKeyWithSshnpd();
      }
    }

    initialized = true;
  }

  /// May only be run after [init] has been run.
  /// - Sends request to sshnpd; the response listener was started by [init]
  /// - Waits for success or error response, or time out after 10 secs
  /// - If got a success response, print the ssh command to use to stdout
  /// - Clean up temporary files
  @override
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }

    if (legacyDaemon) {
      logger.info('Requesting legacy daemon to start reverse ssh session');
      await legacyStartReverseSsh();
    } else {
      if (direct) {
        logger.info(
            'Requesting daemon to set up socket tunnel for direct ssh session');
        await startDirectSsh();
      } else {
        logger.info('Requesting daemon to start reverse ssh session');
        await startReverseSsh();
      }
    }
  }

  Future<void> startDirectSsh() async {
    // send request to the daemon via notification
    await _notify(
        AtKey()
          ..key = 'ssh_request'
          ..namespace = namespace
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000),
        signAndWrapAndJsonEncode(atClient, {
          'direct': true,
          'sessionId': sessionId,
          'host': host,
          'port': int.parse(port)
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      throw ('sshnp: connection timeout');
    }

    if (!sshnpdAckErrors) {
      // 1) Execute an ssh command setting up local port forwarding.
      //    Note that this is very similar to what the daemon does when we
      //    ask for a reverse ssh
      logger.info(
          'Starting direct ssh session for $username to $host on port $_sshrvdPort with forwardLocal of $localPort');

      try {
        bool success = false;
        String? errorMessage;

        switch (sshClient) {
          case SupportedSshClient.hostSsh:
            (success, errorMessage) = await directSshViaExec();
            break;
          case SupportedSshClient.pureDart:
            throw UnimplementedError(
                'start the direct ssh via pure dart client not yet implemented');
        }

        if (!success) {
          errorMessage ??=
              'Failed to start ssh tunnel and / or forward local port $localPort';
          throw errorMessage;
        } else {
          // All good - write the ssh command to stdout
          stdout.writeln(getBaseSshCommand());
        }
      } catch (e) {
        throw 'SSH Client failure : $e';
      }
    }
  }

  Future<(bool, String?)> directSshViaExec() async {
    List<String> args = '$remoteUsername@$host'
            ' -p $_sshrvdPort'
            ' -i ${publicKeyFileName.replaceFirst(RegExp(r'.pub$'), '')}'
            ' -L $localPort:localhost:$localSshdPort'
            ' -o LogLevel=VERBOSE'
            ' -t -t'
            ' -o StrictHostKeyChecking=accept-new'
            ' -o IdentitiesOnly=yes'
            ' -o BatchMode=yes'
            ' -o ExitOnForwardFailure=yes'
            ' -f' // fork after authentication - this is important
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

  /// Identical to [legacyStartReverseSsh] except for the request notification
  Future<void> startReverseSsh() async {
    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.

    unawaited(
        Process.run(getSshrvCommand(), [host, _sshrvdPort, localSshdPort]));

    // send request to the daemon via notification
    await _notify(
        AtKey()
          ..key = 'ssh_request'
          ..namespace = namespace
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000),
        signAndWrapAndJsonEncode(atClient, {
          'direct': false,
          'sessionId': sessionId,
          'host': host,
          'port': int.parse(port),
          'username': username,
          'remoteForwardPort': int.parse(localPort),
          'privateKey': sshPrivateKey
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    await cleanUpAfterReverseSsh(this);
    if (!acked) {
      throw ('sshnp: connection timeout');
    }

    if (!sshnpdAckErrors) {
      // If no ack errors, write the ssh command to stdout
      stdout.write(getBaseSshCommand());
    }
    stdout.write('\n');
  }

  Future<void> legacyStartReverseSsh() async {
    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    
    unawaited(Process.run(getSshrvCommand(), [host, _sshrvdPort, localSshdPort]));

    // send request to the daemon via notification
    await _notify(
        AtKey()
          ..key = 'sshd'
          ..namespace = namespace
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000),
        '$localPort $port $username $host $sessionId',
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    await cleanUpAfterReverseSsh(this);
    if (!acked) {
      throw ('sshnp: connection timeout');
    }

    if (!sshnpdAckErrors) {
      // If no ack errors, write the ssh command to stdout
      stdout.write(getBaseSshCommand());
    }
    stdout.write('\n');
  }

  /// Generate the base ssh command which we will write to stdout.
  /// If we had a Public key, include the private key in the command line
  /// by removing the .pub extn.
  String getBaseSshCommand() {
    final StringBuffer sb = StringBuffer();

    if (publicKeyFileName != 'false') {
      sb.write('ssh -p $localPort $remoteUsername@localhost'
          ' -o StrictHostKeyChecking=accept-new'
          ' -o IdentitiesOnly=yes'
          ' -i ${publicKeyFileName.replaceFirst(RegExp(r'.pub$'), '')}');
    } else {
      sb.write('ssh -p $localPort $remoteUsername@localhost '
          ' -o StrictHostKeyChecking=accept-new');
    }
    // print out optional arguments
    for (var argument in localSshOptions) {
      sb.write(" $argument");
    }

    return sb.toString();
  }

  /// Function which the response subscription (created in the [init] method
  /// will call when it gets a response from the sshnpd
  @visibleForTesting
  handleSshnpdResponses(notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.sshnp${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');
    if (notification.value == 'connected') {
      logger.info('Session $sessionId connected successfully');
      sshnpdAck = true;
    } else {
      stderr.writeln('Remote sshnpd error: ${notification.value}');
      sshnpdAck = true;
      sshnpdAckErrors = true;
    }
  }

  /// Look up the user name ... we expect a key to have been shared with us by
  /// sshnpd. Let's say we are @human running sshnp, and @daemon is running
  /// sshnpd, then we expect a key to have been shared whose ID is
  /// @human:username.device.sshnp@daemon
  /// Is not called if remoteUserName was set via constructor
  Future<void> fetchRemoteUserName() async {
    AtKey userNameRecordID =
        AtKey.fromString('$clientAtSign:username.$namespace$sshnpdAtSign');
    try {
      remoteUsername = (await atClient.get(userNameRecordID)).value as String;
    } catch (e) {
      stderr.writeln("Device \"$device\" unknown, or username not shared ");
      await cleanUpAfterReverseSsh(this);
      rethrow;
    }
  }

  Future<void> sharePublicKeyWithSshnpdIfRequired() async {
    if (publicKeyFileName != 'false') {
      try {
        String toSshPublicKey = await File(publicKeyFileName).readAsString();
        if (!toSshPublicKey.startsWith('ssh-')) {
          throw ('$publicKeyFileName does not look like a public key file');
        }
        AtKey sendOurPublicKeyToSshnpd = AtKey()
          ..key = 'sshpublickey'
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000);
        await _notify(sendOurPublicKeyToSshnpd, toSshPublicKey);
      } catch (e) {
        stderr.writeln(
            "Error opening or validating public key file or sending to remote atSign: $e");
        await cleanUpAfterReverseSsh(this);
        rethrow;
      }
    }
  }

  Future<void> sharePrivateKeyWithSshnpd() async {
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..namespace = namespace
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);
    await _notify(sendOurPrivateKeyToSshnpd, sshPrivateKey);
  }

  Future<void> getHostAndPortFromSshrvd() async {
    atClient.notificationService
        .subscribe(
            regex: '$sessionId.${SSHRVD.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      host = results[0];
      port = results[1];
      _sshrvdPort = results[2];
      sshrvdAck = true;
    });

    AtKey ourSshrvdIdKey = AtKey()
      ..key = '$device.${SSHRVD.namespace}'
      ..sharedBy = clientAtSign // shared by us
      ..sharedWith = host // shared with the sshrvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttr = -1
        ..ttl = 10000);
    await _notify(ourSshrvdIdKey, sessionId);

    int counter = 0;
    while (!sshrvdAck) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        await cleanUpAfterReverseSsh(this);
        stderr.writeln('sshnp: connection timeout to sshrvd $host service');
        throw ('sshnp: connection timeout to sshrvd $host service');
      }
    }
  }

  Future<void> generateSshKeys() async {
    if (rsa) {
      await Process.run(
          'ssh-keygen',
          [
            '-t',
            'rsa',
            '-b',
            '4096',
            '-f',
            '${sessionId}_sshnp',
            '-q',
            '-N',
            ''
          ],
          workingDirectory: sshHomeDirectory);
    } else {
      await Process.run(
          'ssh-keygen',
          [
            '-t',
            'ed25519',
            '-a',
            '100',
            '-f',
            '${sessionId}_sshnp',
            '-q',
            '-N',
            ''
          ],
          workingDirectory: sshHomeDirectory);
    }

    sshPublicKey =
        await File('$sshHomeDirectory${sessionId}_sshnp.pub').readAsString();
    sshPrivateKey =
        await File('$sshHomeDirectory${sessionId}_sshnp').readAsString();

    // Set up a safe authorized_keys file, for the reverse ssh tunnel
    File('${sshHomeDirectory}authorized_keys').writeAsStringSync(
        'command="echo \\"ssh session complete\\";sleep 20",PermitOpen="localhost:$localSshdPort" ${sshPublicKey.trim()} $sessionId\n',
        mode: FileMode.append);
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

  @override
  Future<(Iterable<String>, Iterable<String>, Map<String, dynamic>)>
      listDevices() async {
    // get all the keys device_info.*.sshnpd
    var scanRegex = 'device_info\\.$asciiMatcher\\.${SSHNPD.namespace}';

    var atKeys =
        await _getAtKeysRemote(regex: scanRegex, sharedBy: sshnpdAtSign);

    var devices = <String>{};
    var heartbeats = <String>{};
    var info = <String, dynamic>{};

    // Listen for heartbeat notifications
    atClient.notificationService
        .subscribe(regex: 'heartbeat\\.$asciiMatcher', shouldDecrypt: true)
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
        ..namespace = SSHNPD.namespace
        ..metadata = metaData;

      unawaited(_notify(pingKey, 'ping'));

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

  Future<bool> waitForDaemonResponse() async {
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
}
