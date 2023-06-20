// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// other packages
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:version/version.dart';

// local packages
import 'package:sshnoports/service_factories.dart';
import 'package:sshnoports/sshnp_utils.dart';
import 'package:sshnoports/cleanup_sshnp.dart';
import 'package:sshnoports/version.dart';

class SSHNP {
  // TODO Make this a const in SSHRVD class
  static const String sshrvdNameSpace = 'sshrvd';

  final AtSignLogger logger = AtSignLogger(' sshnp ');

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The [AtClient] used to communicate with sshnpd and sshrvd
  final AtClient atClient;

  /// The atSign of the sshnpd we wish to communicate with
  final String sshnpdAtSign;

  /// The device name of the sshnpd we wish to communicate with
  final String device;

  /// The user name on this host
  final String username;

  /// The home directory on this host
  final String homeDirectory;

  /// The sessionId we will use
  final String sessionId;

  final String sendSshPublicKey;
  final List<String> localSshOptions;

  /// When false, we generate [sshPublicKey] and [sshPrivateKey] using ed25519.
  /// When true, we generate [sshPublicKey] and [sshPrivateKey] using RSA.
  /// Defaults to false
  final bool rsa;

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
  String port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  String localPort;

  // ====================================================================
  // Derived final instance variables, set during construction or init
  // ====================================================================

  /// Set to [AtClient.getCurrentAtSign] during construction
  @visibleForTesting
  late final String clientAtSign;

  /// The username to use on the remote host in the ssh session. Either passed
  /// through class constructor or fetched from the sshnpd
  /// by [fetchRemoteUserName] during [init]
  String? remoteUsername;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will write
  /// [sshPublicKey] to ~/.ssh/authorized_keys
  late final String sshPublicKey;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will send the
  /// [sshPrivateKey] to sshnpd
  late final String sshPrivateKey;

  /// Namespace will be set to [device].sshnp
  late final String nameSpace;

  /// When using sshrvd, this is fetched from sshrvd during [init]
  late final String sshrvdPort;

  /// Set to '$localPort $port $username $host $sessionId' during [init]
  late final String sshString;

  /// Set by constructor to
  /// '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}'
  late final String sshHomeDirectory;

  /// true once we have received any response (success or error) from sshnpd
  @visibleForTesting
  bool sshnpdAck = false;

  /// true once we have received an error response from sshnpd
  @visibleForTesting
  bool sshnpdAckErrors = false;

  /// true once we have received a response from sshrvd
  @visibleForTesting
  bool sshrvdAck = false;

  // In the future (perhaps) we can send other commands
  // Perhaps OpenVPN or shell commands
  static const String commandToSend = 'sshd';

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  SSHNP({
    // final fields
    required this.atClient,
    required this.sshnpdAtSign,
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.sessionId,
    this.sendSshPublicKey = 'false',
    required this.localSshOptions,
    this.rsa = false,
    // volatile fields
    required this.host,
    required this.port,
    required this.localPort,
    this.remoteUsername,
  }) {
    nameSpace = '$device.sshnp';
    clientAtSign = atClient.getCurrentAtSign()!;
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    if (! Directory(sshHomeDirectory).existsSync()) {
      Directory(sshHomeDirectory).createSync();
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
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    if(!(await atSignIsActivated(atClient, sshnpdAtSign))) {
        throw ('sshnpd atSign $sshnpdAtSign is not activated.');
    }

    logger.info('Subscribing to notifications on $sessionId.$nameSpace@');
    // Start listening for response notifications from sshnpd
    atClient.notificationService
        .subscribe(regex: '$sessionId.$nameSpace@', shouldDecrypt: true)
        .listen(handleSshnpdResponses);

    await generateSshKeys();

    if (remoteUsername == null) {
      await fetchRemoteUserName();
    }

    // find a spare local port
    if (localPort == '0') {
      ServerSocket serverSocket =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      localPort = serverSocket.port.toString();
      await serverSocket.close();
    }

    // If host has an @ then contact the sshrvd service for some ports
    if (host.startsWith('@')) {
      await getHostAndPortFromSshrvd();
    }

    if (commandToSend == 'sshd') {
      // Local port, port of sshd , username , hostname
      sshString = '$localPort $port $username $host $sessionId';
    }

    await sharePrivateKeyWithSshnpd();

    await sharePublicKeyWithSshnpdIfRequired();

    initialized = true;
  }

  /// May only be run after [init] has been run.
  /// - Sends request to sshnpd; the response listener was started by [init]
  /// - Waits for success or error response, or time out after 10 secs
  /// - If got a success response, print the ssh command to use to stdout
  /// - Clean up temporary files
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }
    AtKey keyForCommandToSend = AtKey()
      ..key = commandToSend
      ..namespace = nameSpace
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);

    try {
      await atClient.notificationService
          .notify(NotificationParams.forUpdate(keyForCommandToSend, value: sshString),
          onSuccess: (notification) {
            logger.info('SUCCESS:$notification $sshString');
          }, onError: (notification) {
            logger.info('ERROR:$notification $sshString');
          });
    } catch (e) {
      stderr.writeln(e.toString());
    }

    // Before we clean up we need to make sure that the reverse ssh made the connection.
    // Or that if it had a problem what the problem was, or timeout and explain why.

    int counter = 0;
    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    while (!sshnpdAck) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        await cleanUp(sessionId, logger);
        stderr.writeln('sshnp: connection timeout');
        exit(1);
      }
    }

    // Clean Up the files we created
    await cleanUp(sessionId, logger);

    // print out base ssh command if we hit no Ack Errors
    // If we had a Public key include the private key in the command line
    // By removing the .pub extn
    if (!sshnpdAckErrors) {
      if (sendSshPublicKey != 'false') {
        stdout.write(
            "ssh -p $localPort $remoteUsername@localhost -i ${sendSshPublicKey.replaceFirst(RegExp(r'.pub$'), '')} ");
      } else {
        stdout.write("ssh -p $localPort $remoteUsername@localhost ");
      }
      // print out optional arguments
      for (var argument in localSshOptions) {
        stdout.write("$argument ");
      }
    }
    // Print the  return
    stdout.write('\n');
    exit(0);
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
    AtKey userNameRecordID = AtKey.fromString('$clientAtSign:username.$nameSpace$sshnpdAtSign');
    try {
      remoteUsername = (await atClient.get(userNameRecordID)).value as String;
    } catch (e) {
      stderr.writeln("Device \"$device\" unknown, or username not shared ");
      await cleanUp(sessionId, logger);
      exit(1);
    }
  }

  Future<void> sharePublicKeyWithSshnpdIfRequired() async {
    if (sendSshPublicKey != 'false') {
      try {
        String toSshPublicKey = await File(sendSshPublicKey).readAsString();
        if (!toSshPublicKey.startsWith('ssh-')) {
          throw ('$sshHomeDirectory$sendSshPublicKey does not look like a public key file');
        }
        AtKey sendOurPublicKeyToSshnpd = AtKey()
          ..key = 'sshpublickey'
          ..sharedBy = clientAtSign
          ..sharedWith = sshnpdAtSign
          ..metadata = (Metadata()
            ..ttr = -1
            ..ttl = 10000);
        await atClient.notificationService.notify(
            NotificationParams.forUpdate(sendOurPublicKeyToSshnpd,
                value: toSshPublicKey), onSuccess: (notification) {
          logger.info('SUCCESS:$notification');
        }, onError: (notification) {
          logger.info('ERROR:$notification');
        });
      } catch (e) {
        stderr.writeln(
            "Error opening or validating public key file or sending to remote atSign: $e");
        await cleanUp(sessionId, logger);
        exit(1);
      }
    }
  }

  Future<void> sharePrivateKeyWithSshnpd() async {
    AtKey sendOurPrivateKeyToSshnpd = AtKey()
      ..key = 'privatekey'
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..namespace = nameSpace
      ..metadata = (Metadata()
        ..ttr = -1
        ..ttl = 10000);

    try {
      await atClient.notificationService
          .notify(NotificationParams.forUpdate(sendOurPrivateKeyToSshnpd, value: sshPrivateKey),
          onSuccess: (notification) {
            logger.info('SUCCESS:$notification');
          }, onError: (notification) {
            logger.info('ERROR:$notification');
          });
    } catch (e) {
      stderr.writeln(e.toString());
    }
  }

  Future<void> getHostAndPortFromSshrvd() async {
    atClient.notificationService
        .subscribe(regex: '$sessionId.$sshrvdNameSpace@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      host = results[0];
      port = results[1];
      sshrvdPort = results[2];
      sshrvdAck = true;
    });

    AtKey ourSshrvdIdKey = AtKey()
      ..key = '$device.$sshrvdNameSpace'
      ..sharedBy = clientAtSign // shared by us
      ..sharedWith = host // shared with the sshrvd host
      ..metadata = (Metadata()
        // as we are sending a notification to the sshrvd namespace,
        // we don't want to append our namespace
        ..namespaceAware = false
        ..ttr = -1
        ..ttl = 10000);

    try {
      await atClient.notificationService
          .notify(NotificationParams.forUpdate(ourSshrvdIdKey, value: sessionId),
          onSuccess: (notification) {
            logger.info('SUCCESS:$notification $ourSshrvdIdKey');
          }, onError: (notification) {
            logger.info('ERROR:$notification $ourSshrvdIdKey');
          });
    } catch (e) {
      stderr.writeln(e.toString());
    }

    int counter = 0;
    while (!sshrvdAck) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        await cleanUp(sessionId, logger);
        stderr.writeln('sshnp: connection timeout to sshrvd $host service');
        exit(1);
      }
    }

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    unawaited(Process.run(getSshrvCommand(), [host, sshrvdPort]));
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
        'command="echo \\"ssh session complete\\";sleep 20",PermitOpen="localhost:22" ${sshPublicKey.trim()} $sessionId\n',
        mode: FileMode.append);
  }

  static SSHNPParams parseSSHNPParams(List<String> args) {
    var p = SSHNPParams();

    // Arg check
    ArgResults r = createArgParser().parse(args);

    // Do we have a username ?
    p.username = getUserName(throwIfNull:true)!;

    // Do we have a 'home' directory?
    p.homeDirectory = getHomeDirectory(throwIfNull:true)!;

    p.clientAtSign = r['from'];
    p.sshnpdAtSign = r['to'];

    // Find atSign key file
    if (r['key-file'] != null) {
      p.atKeysFilePath = r['key-file'];
    } else {
      p.atKeysFilePath = getDefaultAtKeysFilePath(p.homeDirectory, p.clientAtSign);
    }

    // Check device string only contains ascii
    if (checkNonAscii(r['device'])) {
      throw ('\nDevice name can only contain alphanumeric characters with a max length of 15');
    }

    p.device = r['device'];

    // Check the public key if the option was selected
    var sendSshPublicKey = r['ssh-public-key'];
    if ((sendSshPublicKey != 'false')) {
      sendSshPublicKey = '${getDefaultSshDirectory(p.homeDirectory)}$sendSshPublicKey';
      if (!sendSshPublicKey.endsWith('.pub')) {
        throw ('\n The ssh public key should have a ".pub" extension');
      }
    }
    p.sendSshPublicKey = sendSshPublicKey;

    p.host = r['host'];
    p.port = r['port'];
    p.localPort = r['local-port'];

    p.localSshOptions = r['local-ssh-options'];

    p.rsa = r['rsa'];
    p.verbose = r['verbose'];

    p.remoteUsername = r['remote-user-name'];

    return p;
  }

  static Future<SSHNP> fromCommandLineArgs(List<String> args) async {
    try {
      var p = parseSSHNPParams(args);

      // Check atKeyFile selected exists
      if (!File(p.atKeysFilePath).existsSync()) {
        throw ('\n Unable to find .atKeys file : ${p.atKeysFilePath}');
      }

      if (p.sendSshPublicKey != 'false') {
        if (!File(p.sendSshPublicKey).existsSync()) {
          throw ('\n Unable to find ssh public key file : ${p.sendSshPublicKey}');
        }
      }

      String sessionId = Uuid().v4();

      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClient(
          clientAtSign: p.clientAtSign,
          device: p.device,
          sessionId: sessionId,
          atKeysFilePath: p.atKeysFilePath);

      var sshnp = SSHNP(
        atClient: atClient,
        sshnpdAtSign: p.sshnpdAtSign,
        username: p.username,
        homeDirectory: p.homeDirectory,
        sessionId: sessionId,
        device: p.device,
        host: p.host,
        port: p.port,
        localPort: p.localPort,
        localSshOptions: p.localSshOptions,
        rsa: p.rsa,
        sendSshPublicKey: p.sendSshPublicKey,
        remoteUsername: p.remoteUsername,
      );
      if (p.verbose) {
        sshnp.logger.logger.level = Level.INFO;
      }

      return sshnp;
    } catch (e) {
      version();
      stdout.writeln(createArgParser().usage);
      stderr.writeln(e);
      exit(1);
    }
  }

  static Future<AtClient> createAtClient(
      {required String clientAtSign,
        required String device,
        required String sessionId,
        required String atKeysFilePath}) async {
    // Now on to the atPlatform startup
    //onboarding preference builder can be used to set onboardingService parameters
    AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
      ..hiveStoragePath = '/tmp/.sshnp/$clientAtSign/$sessionId/storage'
          .replaceAll('/', Platform.pathSeparator)
      ..namespace = '$device.sshnp'
      ..downloadPath =
          '/tmp/.sshnp/files'.replaceAll('/', Platform.pathSeparator)
      ..isLocalStoreRequired = true
      ..commitLogPath = '/tmp/.sshnp/$clientAtSign/$sessionId/storage/commitLog'
          .replaceAll('/', Platform.pathSeparator)
      ..fetchOfflineNotifications = false
      ..atKeysFilePath = atKeysFilePath
      ..atProtocolEmitted = Version(2, 0, 0);

    AtOnboardingService onboardingService = AtOnboardingServiceImpl(
        clientAtSign, atOnboardingConfig,
        atServiceFactory: ServiceFactoryWithNoOpSyncService());

    await onboardingService.authenticate();

    return AtClientManager.getInstance().atClient;
  }

  static ArgParser createArgParser() {
    var parser = ArgParser();
    // Basic arguments
    parser.addOption('key-file',
        abbr: 'k',
        mandatory: false,
        help: 'Sending atSign\'s atKeys file if not in ~/.atsign/keys/');
    parser.addOption('from',
        abbr: 'f', mandatory: true, help: 'Sending atSign');
    parser.addOption('to',
        abbr: 't', mandatory: true, help: 'Send a notification to this atSign');
    parser.addOption('device',
        abbr: 'd',
        mandatory: false,
        defaultsTo: "default",
        help: 'Send a notification to this device');
    parser.addOption('host',
        abbr: 'h',
        mandatory: true,
        help: 'atSign of sshrvd daemon or FQDN/IP address to connect back to ');
    parser.addOption('port',
        abbr: 'p',
        mandatory: false,
        defaultsTo: '22',
        help:
        'TCP port to connect back to (only required if --host specified a FQDN/IP)');
    parser.addOption('local-port',
        abbr: 'l',
        defaultsTo: '0',
        mandatory: false,
        help:
        'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port');
    parser.addOption('ssh-public-key',
        abbr: 's',
        defaultsTo: 'false',
        mandatory: false,
        help:
        'Public key file from ~/.ssh to be appended to authorized_hosts on the remote device');
    parser.addMultiOption('local-ssh-options',
        abbr: 'o', help: 'Add these commands to the local ssh command');
    parser.addFlag('verbose', abbr: 'v', help: 'More logging');
    parser.addFlag('rsa',
        abbr: 'r',
        defaultsTo: false,
        help: 'Use RSA 4096 keys rather than the default ED25519 keys');
    parser.addOption('remote-user-name',
        abbr: 'u',
        mandatory: false,
        help: 'user name to use in the ssh session on the remote host');
    return parser;
  }

  /// Return the command which this program should execute in order to start the
  /// sshrv program.
  /// - In normal usage, sshnp and sshrv are compiled to exe before use, thus the
  /// path is [Platform.resolvedExecutable] but with the last part (`sshnp` in
  /// this case) replaced with `sshrv`
  static String getSshrvCommand() {
    late String sshnpDir;
    List<String> pathList =
        Platform.resolvedExecutable.split(Platform.pathSeparator);
    if (pathList.last == 'sshnp' || pathList.last == 'sshnp.exe') {
      pathList.removeLast();
      sshnpDir = pathList.join(Platform.pathSeparator);

      return '$sshnpDir${Platform.pathSeparator}sshrv';
    } else {
      throw Exception(
          'sshnp is expected to be run as a compiled executable, not via the dart command');
    }
  }
}

class SSHNPParams {
  late final String clientAtSign;
  late final String sshnpdAtSign;
  late final String device;
  late final String host;
  late final String port;
  late final String localPort;
  late final String username;
  late final String homeDirectory;
  late final String atKeysFilePath;
  late final String sendSshPublicKey;
  late final List<String> localSshOptions;
  late final bool rsa;
  late final bool verbose;
  late final String? remoteUsername;
}