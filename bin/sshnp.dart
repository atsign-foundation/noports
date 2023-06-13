// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// external packages
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:sshnoports/service_factories.dart';
import 'package:uuid/uuid.dart';
import 'package:version/version.dart';

// local packages
import 'package:sshnoports/version.dart';
import 'package:sshnoports/home_directory.dart';
import 'package:sshnoports/check_non_ascii.dart';
import 'package:sshnoports/cleanup_sshnp.dart';
import 'package:sshnoports/check_file_exists.dart';

final Uuid uuid = Uuid();
final String sessionId = uuid.v4();

void main(List<String> args) async {
  AtSignLogger.root_level = 'SHOUT';

  SSHNP sshnp = await SSHNP.fromCommandLineArgs(args);

  ProcessSignal.sigint.watch().listen((signal) async {
    await cleanUp(sessionId, sshnp.logger);
    exit(1);
  });

  await sshnp.init();

  await sshnp.run();
}

class SSHNP {
  // TODO Make this a const in SSHRVD class
  static const String sshrvdNameSpace = 'sshrvd';

  final AtSignLogger logger = AtSignLogger(' sshnp ');

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

  /// Set to [AtClient.getCurrentAtSign] during construction
  @visibleForTesting
  late final String clientAtSign;

  /// The username to use on the remote host in the ssh session. Is fetched
  /// during [init]
  late final String remoteUsername;

  late final String sshPublicKey;
  late final String sshPrivateKey;
  /// Namespace will be set to [device].sshnp
  late final String nameSpace;

  String port;
  String host;
  String sshrvdPort = '';
  String localPort;
  String sshString = "";
  String sshHomeDirectory = "";
  final String sendSshPublicKey;
  List<String> localSshOptions = [];

  int counter = 0;
  bool ack = false;
  bool ackErrors = false;
  bool rsa = false;

  // In the future (perhaps) we can send other commands
  // Perhaps OpenVPN or shell commands
  static const String commandToSend = 'sshd';

  @visibleForTesting
  bool initialized = false;

  SSHNP({
    required this.atClient,
    required this.sshnpdAtSign,
    required this.username,
    required this.homeDirectory,
    required this.device,
    required this.host,
    required this.port,
    required this.localPort,
    required this.localSshOptions,
    this.sendSshPublicKey = 'false'
  }) {
    nameSpace = '$device.sshnp';
    clientAtSign = atClient.getCurrentAtSign()!;
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;
    // Setup ssh keys location
    sshHomeDirectory = '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}';
    if (! Directory(sshHomeDirectory).existsSync()) {
      Directory(sshHomeDirectory).createSync();
    }
  }

  /// Must be run after construction, to complete initialization
  Future<void> init() async {
    if (initialized) {
      throw StateError('Cannot init() - already initialized');
    }

    logger.info('Subscribing to notifications on $sessionId.$nameSpace@');
    // Start listening for response notifications from sshnpd
    atClient.notificationService
        .subscribe(regex: '$sessionId.$nameSpace@', shouldDecrypt: true)
        .listen(handleSshnpdResponses);

    await setupSshKeys();

    await fetchRemoteUserName();

    // If host has an @ then contact the sshrvd service for some ports
    if (host.startsWith('@')) {
      await getHostAndPortFromSshrvd();
    }

    await sharePrivateKeyWithSshnpd();

    await sharePublicKeyWithSshnpdIfRequired();

    initialized = true;
  }

  /// May only be run after [init] has been run
  Future<void> run() async {
    if (!initialized) {
      throw StateError('Cannot run() - not initialized');
    }
    // find a spare local port
    if (localPort == '0') {
      ServerSocket serverSocket =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      localPort = serverSocket.port.toString();
      await serverSocket.close();
    }

    AtKey keyForCommandToSend = AtKey()
      ..key = commandToSend
      ..namespace = nameSpace
      ..sharedBy = clientAtSign
      ..sharedWith = sshnpdAtSign
      ..metadata = (Metadata()..ttr=-1..ttl=10000);

    if (commandToSend == 'sshd') {
      // Local port, port of sshd , username , hostname
      sshString = '$localPort $port $username $host $sessionId';
    }

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

    // Timer to timeout after 10 Secs or after the Ack of connected/Errors
    while (!ack) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 300) {
        ack = true;
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
    if (!ackErrors) {
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
      // Give ssh/sshd a little time to get everything in place
      //   await Future.delayed(Duration(milliseconds: 250));
      ack = true;
    } else {
      stderr.writeln('Remote sshnpd error: ${notification.value}');
      ack = true;
      ackErrors = true;
    }
  }


  /// Look up the user name ... we expect a key to have been shared with us by
  /// sshnpd. Let's say we are @human running sshnp, and @daemon is running
  /// sshnpd, then we expect a key to have been shared whose ID is
  /// @human:username.device.sshnp@daemon
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
    String sshrvdId = uuid.v4();
    atClient.notificationService
        .subscribe(regex: '$sshrvdId.$sshrvdNameSpace@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      host = results[0];
      port = results[1];
      sshrvdPort = results[2];
      ack = true;
    });

    AtKey ourSshrvdIdKey = AtKey()
      ..key = '$device$sshrvdNameSpace'
      ..sharedBy = clientAtSign // shared by us
      ..sharedWith = host // shared with the sshrvd host
      ..metadata = (Metadata()..ttr=-1..ttl=10000);

    try {
      await atClient.notificationService
          .notify(NotificationParams.forUpdate(ourSshrvdIdKey, value: sshrvdId),
              onSuccess: (notification) {
        logger.info('SUCCESS:$notification $sshString');
      }, onError: (notification) {
        logger.info('ERROR:$notification $sshString');
      });
    } catch (e) {
      stderr.writeln(e.toString());
    }

    while (!ack) {
      await Future.delayed(Duration(milliseconds: 100));
      counter++;
      if (counter == 100) {
        ack = true;
        await cleanUp(sessionId, logger);
        stderr.writeln('sshnp: connection timeout to sshrvd $host service');
        exit(1);
      }
    }
    ack = false;

    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    unawaited(Process.run(getSshrvCommand(), [host, sshrvdPort]));
  }

  Future<void> setupSshKeys() async {
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

  static Future<SSHNP> fromCommandLineArgs(List<String> args) async {
    ArgParser parser = createArgParser();

    try {
      // Arg check
      ArgResults results = parser.parse(args);

      // Do we have a username ?
      var username = getUserName();
      if (username == null) {
        throw ('\nUnable to determine your username: please set environment variable\n\n');
      }

      // Do we have a 'home' directory?
      var homeDirectory = getHomeDirectory();
      if (homeDirectory == null) {
        throw ('\nUnable to determine your home directory: please set environment variable\n\n');
      }

      // Setup ssh keys location
      var sshHomeDirectory =
          "$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}";

      var clientAtSign = results['from'];
      var sshnpdAtSign = results['to'];

      String? atKeysFilePath;
      // Find atSign key file
      if (results['key-file'] != null) {
        atKeysFilePath = results['key-file'];
      } else {
        atKeysFilePath = '${clientAtSign}_key.atKeys';
        atKeysFilePath = '$homeDirectory/.atsign/keys/$atKeysFilePath';
      }
      // Check atKeyFile selected exists
      if (!File(atKeysFilePath!).existsSync()) {
        throw ('\n Unable to find .atKeys file : $atKeysFilePath');
      }

      // Check device string only contains ascii
      if (checkNonAscii(results['device'])) {
        throw ('\nDevice name can only contain alphanumeric characters with a max length of 15');
      }

      var device = results['device'];

      // Check the public key if the option was selected
      var sendSshPublicKey = results['ssh-public-key'];
      if ((sendSshPublicKey != 'false')) {
        sendSshPublicKey = '$sshHomeDirectory$sendSshPublicKey';
        if (!await fileExists(sendSshPublicKey)) {
          throw ('\n Unable to find ssh public key file : $sendSshPublicKey');
        }
        if (!sendSshPublicKey.endsWith('.pub')) {
          throw ('\n The ssh public key should have a ".pub" extension');
        }
      }

      if (results['verbose']) {
        AtSignLogger.root_level = 'INFO';
      }

      AtClient atClient = await createAtClient(
          clientAtSign: clientAtSign,
          device: device,
          sessionId: sessionId,
          atKeysFilePath: atKeysFilePath);

      var sshnp = SSHNP(
          atClient: atClient,
          sshnpdAtSign: sshnpdAtSign,
          username: username,
          homeDirectory: homeDirectory,
          device: device,
          host: results['host'],
          port: results['port'],
          localPort: results['local-port'],
          sendSshPublicKey: sendSshPublicKey,
          localSshOptions: results['local-ssh-options'] ?? []);
      if (results['verbose']) {
        sshnp.logger.logger.level = Level.INFO;
      }

      return sshnp;
    } catch (e) {
      version();
      stdout.writeln(parser.usage);
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
      ..namespace = '$device.sshnp'
      ..downloadPath = '/tmp/.sshnp/files'
      ..isLocalStoreRequired = true
      ..commitLogPath = '/tmp/.sshnp/$clientAtSign/$sessionId/storage/commitLog'
      ..fetchOfflineNotifications = false
      ..atKeysFilePath = atKeysFilePath
      ..atProtocolEmitted = Version(2, 0, 0);

    AtOnboardingService onboardingService =
    AtOnboardingServiceImpl(clientAtSign, atOnboardingConfig, atServiceFactory: ServiceFactoryWithNoOpSyncService());

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
    return parser;
  }

  /// Return the command which this program should execute in order to start the
  /// sshrv program.
  /// - In normal usage, sshnp and sshrv are compiled to exe before use, thus the
  /// path is [Platform.resolvedExecutable] but with the last part (`sshnp` in
  /// this case) replaced with `sshrv`
  static String getSshrvCommand() {
    late String sshnpDir;
    if (Platform.executable.endsWith('${Platform.pathSeparator}sshnp')) {
      List<String> pathList =
          Platform.resolvedExecutable.split(Platform.pathSeparator);
      pathList.removeLast();
      sshnpDir = pathList.join(Platform.pathSeparator) + Platform.pathSeparator;

      return '$sshnpDir${Platform.pathSeparator}sshrv';
    } else {
      throw Exception(
          'sshnp is expected to be run as a compiled executable, not via the dart command');
    }
  }
}

String? getUserName() {
  Map<String, String> envVars = Platform.environment;
  if (Platform.isLinux || Platform.isMacOS) {
    return envVars['USER'];
  } else if (Platform.isWindows) {
    return envVars['USERPROFILE'];
  }
  return null;
}
