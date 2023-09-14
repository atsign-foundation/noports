part of 'sshnp.dart';

@visibleForTesting
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
  late final int localSshdPort;

  @override
  late final int remoteSshdPort;

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
  int port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  @override
  int localPort;

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
  int get sshrvdPort => _sshrvdPort;

  late int _sshrvdPort;

  /// Set by constructor to
  /// '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}'
  @override
  late final String sshHomeDirectory;

  /// Function used to generate a [SSHRV] instance ([SSHRV.localbinary] by default)
  @override
  SSHRVGenerator sshrvGenerator;

  /// true once we have received any response (success or error) from sshnpd
  @override
  @visibleForTesting
  bool sshnpdAck = false;

  /// true once we have received an error response from sshnpd
  @override
  @visibleForTesting
  bool sshnpdAckErrors = false;

  @visibleForTesting
  late String ephemeralPrivateKey;

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

  @override
  late final SupportedSshClient sshClient;

  @override
  late final int idleTimeout;

  @override
  late final bool addForwardsToTunnel;

  final _doneCompleter = Completer<void>();

  @override
  Future<void> get done => _doneCompleter.future;

  SSHNPImpl({
    required this.atClient,
    required this.sshnpdAtSign,
    required this.device,
    required this.username,
    required this.homeDirectory,
    required this.sessionId,
    String sendSshPublicKey = SSHNP.defaultSendSshPublicKey,
    required this.localSshOptions,
    this.rsa = defaults.defaultRsa,
    required this.host,
    required this.port,
    required this.localPort,
    this.remoteUsername,
    this.verbose = defaults.defaultVerbose,
    this.sshrvGenerator = defaults.defaultSshrvGenerator,
    this.localSshdPort = defaults.defaultLocalSshdPort,
    this.legacyDaemon = SSHNP.defaultLegacyDaemon,
    this.remoteSshdPort = defaults.defaultRemoteSshdPort,
    this.idleTimeout = defaults.defaultIdleTimeout,
    required this.sshClient,
    this.addForwardsToTunnel = false,
  }) {
    namespace = '$device.sshnp';
    clientAtSign = atClient.getCurrentAtSign()!;
    logger.hierarchicalLoggingEnabled = true;
    logger.logger.level = Level.SHOUT;

    sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
    if (!Directory(sshHomeDirectory).existsSync()) {
      try {
        Directory(sshHomeDirectory).createSync();
      } catch (e, s) {
        throw SSHNPFailed(
          'Unable to create ssh home directory $sshHomeDirectory\n'
          'hint: try manually creating $sshHomeDirectory and re-running sshnp',
          e,
          s,
        );
      }
    }

    // previously, the default value for sendSshPublicKey was 'false' instead of ''
    // immediately set it to '' to avoid the program from attempting to
    // search for a public key file called 'false'
    if (sendSshPublicKey == 'false' || sendSshPublicKey.isEmpty) {
      publicKeyFileName = '';
    } else if (path.normalize(sendSshPublicKey).contains('/') || path.normalize(sendSshPublicKey).contains(r'\')) {
      publicKeyFileName = path.normalize(path.absolute(sendSshPublicKey));
    } else {
      publicKeyFileName = path.normalize('$sshHomeDirectory$sendSshPublicKey');
    }
  }

  static Future<SSHNP> fromCommandLineArgs(List<String> args) {
    var params = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgs(args));
    // This should never need sshrvGenerator to be set other than default, hence not passed in
    return fromParams(params);
  }

  static Future<SSHNP> fromParams(
    SSHNPParams p, {
    AtClient? atClient,
    SSHRVGenerator sshrvGenerator = SSHRV.localBinary,
  }) async {
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

      if (atClient != null) {
        if (p.clientAtSign != atClient.getCurrentAtSign()) {
          throw ArgumentError('Option from must match the current atSign of the AtClient');
        }
      } else {
        // Check atKeyFile selected exists
        if (!await fileExists(p.atKeysFilePath)) {
          throw ArgumentError('\nUnable to find .atKeys file : ${p.atKeysFilePath}');
        }
      }

      // Check to see if the port number is in range for TCP ports
      if (p.localSshdPort > 65535 || p.localSshdPort < 1) {
        throw ArgumentError('\nInvalid port number for sshd (1-65535) : ${p.localSshdPort}');
      }

      String sessionId = Uuid().v4();

      AtSignLogger.root_level = 'SHOUT';
      if (p.verbose) {
        AtSignLogger.root_level = 'INFO';
      }

      atClient ??= await createAtClientCli(
        homeDirectory: p.homeDirectory,
        atsign: p.clientAtSign!,
        namespace: '${p.device}.sshnp',
        pathExtension: sessionId,
        atKeysFilePath: p.atKeysFilePath,
        rootDomain: p.rootDomain,
      );

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
        rsa: p.rsa,
        sendSshPublicKey: p.sendSshPublicKey,
        remoteUsername: p.remoteUsername,
        verbose: p.verbose,
        sshrvGenerator: sshrvGenerator,
        localSshdPort: p.localSshdPort,
        legacyDaemon: p.legacyDaemon,
        remoteSshdPort: p.remoteSshdPort,
        idleTimeout: p.idleTimeout,
        sshClient: SupportedSshClient.values.firstWhere((c) => c.cliArg == p.sshClient),
        addForwardsToTunnel: p.addForwardsToTunnel,
      );
      if (p.verbose) {
        sshnp.logger.logger.level = Level.INFO;
      }

      return sshnp;
    } catch (e, s) {
      printVersion();
      stdout.writeln(SSHNPPartialParams.parser.usage);
      stderr.writeln('\n$e');
      if (e is SSHNPFailed) {
        rethrow;
      }
      throw SSHNPFailed('Unknown failure:\n$e', e, s);
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
    try {
      if (!(await atSignIsActivated(atClient, sshnpdAtSign))) {
        throw ('Device address $sshnpdAtSign is not activated.');
      }
    } catch (e, s) {
      throw SSHNPFailed('Device address $sshnpdAtSign does not exist or is not activated.', e, s);
    }

    logger.info('Subscribing to notifications on $sessionId.$namespace@');
    // Start listening for response notifications from sshnpd
    atClient.notificationService
        .subscribe(regex: '$sessionId.$namespace@', shouldDecrypt: true)
        .listen(handleSshnpdResponses);

    if (publicKeyFileName.isNotEmpty && !File(publicKeyFileName).existsSync()) {
      throw ('Unable to find ssh public key file : $publicKeyFileName');
    }

    if (publicKeyFileName.isNotEmpty && !File(publicKeyFileName.replaceAll('.pub', '')).existsSync()) {
      throw ('Unable to find matching ssh private key for public key : $publicKeyFileName');
    }

    remoteUsername ?? await fetchRemoteUserName();

    // find a spare local port
    if (localPort == 0) {
      try {
        ServerSocket serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        localPort = serverSocket.port;
        await serverSocket.close();
      } catch (e, s) {
        throw SSHNPFailed('Unable to find a spare local port', e, s);
      }
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
      try {
        var (String ephemeralPublicKey, String ephemeralPrivateKey) =
            await generateSshKeys(rsa: rsa, sessionId: sessionId, sshHomeDirectory: sshHomeDirectory);

        sshPublicKey = ephemeralPublicKey;
        sshPrivateKey = ephemeralPrivateKey;
      } catch (e, s) {
        throw SSHNPFailed('Failed to generate ephemeral keypair', e, s);
      }

      try {
        await addEphemeralKeyToAuthorizedKeys(
            sshPublicKey: sshPublicKey, localSshdPort: localSshdPort, sessionId: sessionId);
      } catch (e, s) {
        throw SSHNPFailed('Failed to add ephemeral key to authorized_keys', e, s);
      }

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
  Future<SSHNPResult> run() async {
    if (!initialized) {
      return SSHNPFailed('Cannot run() - not initialized');
    }

    late SSHNPResult res;
    if (legacyDaemon) {
      logger.info('Requesting legacy daemon to start reverse ssh session');
      res = await legacyStartReverseSsh();
      _doneCompleter.complete();
    } else {
      if (direct) {
        // Note that when direct, this client is initiating the tunnel ssh.
        //
        // If tunnel is created using /usr/bin/ssh then it is exec'd in the
        // background, and the `directSshViaExec` method will call
        // _doneCompleter.complete() before it returns.
        //
        // However if tunnel is created using pure dart SSHClient then the
        // tunnel is being managed by the SSHNP instance. In that case,
        // _doneCompleter.complete() is called once the tunnel determines
        // that there are no more active connections.
        logger.info('Requesting daemon to set up socket tunnel for direct ssh session');
        res = await startDirectSsh();
      } else {
        logger.info('Requesting daemon to start reverse ssh session');
        res = await startReverseSsh();
        _doneCompleter.complete();
      }
    }

    return res;
  }

  Future<SSHNPResult> startDirectSsh() async {
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
        signAndWrapAndJsonEncode(atClient, {'direct': true, 'sessionId': sessionId, 'host': host, 'port': port}),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    if (!acked) {
      return SSHNPFailed('sshnp timed out: waiting for daemon response\nhint: make sure the device is online');
    }

    if (sshnpdAckErrors) {
      return SSHNPFailed('sshnp failed: with sshnpd acknowledgement errors');
    }
    // 1) Execute an ssh command setting up local port forwarding.
    //    Note that this is very similar to what the daemon does when we
    //    ask for a reverse ssh
    logger.info(
        'Starting direct ssh session for $username to $host on port $_sshrvdPort with forwardLocal of $localPort');

    try {
      bool success = false;
      String? errorMessage;
      Process? process;
      SSHClient? client;
      switch (sshClient) {
        case SupportedSshClient.hostSsh:
          (success, errorMessage, process) = await directSshViaExec();
          _doneCompleter.complete();
          break;
        case SupportedSshClient.pureDart:
          (success, errorMessage, client) = await directSshViaSSHClient();
          break;
      }

      if (!success) {
        errorMessage ??= 'Failed to start ssh tunnel and / or forward local port $localPort';
        return SSHNPFailed(errorMessage);
      }
      // All good - write the ssh command to stdout
      return SSHCommand.base(
        localPort: localPort,
        remoteUsername: remoteUsername,
        host: 'localhost',
        privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
        localSshOptions: (addForwardsToTunnel) ? localSshOptions : null,
        sshProcess: process,
        sshClient: client,
      );
    } catch (e, s) {
      return SSHNPFailed('SSH Client failure : $e', e, s);
    }
  }

  Future<(bool, String?, SSHClient?)> directSshViaSSHClient() async {
    late final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(host, _sshrvdPort);
    } catch (e) {
      return (false, 'Failed to open socket to $host:$port : $e', null);
    }

    late final SSHClient client;
    try {
      client = SSHClient(socket,
          username: remoteUsername!,
          identities: [
            // A single private key file may contain multiple keys.
            ...SSHKeyPair.fromPem(ephemeralPrivateKey)
          ],
          keepAliveInterval: Duration(seconds: 15));
    } catch (e) {
      return (false, 'Failed to create SSHClient for $username@$host:$port : $e', null);
    }

    try {
      await client.authenticated;
    } catch (e) {
      return (false, 'Failed to authenticate as $username@$host:$port : $e', null);
    }

    int counter = 0;

    Future<void> startForwarding(
        {required int fLocalPort, required String fRemoteHost, required int fRemotePort}) async {
      logger.info('Starting port forwarding'
          ' from port $fLocalPort on localhost'
          ' to $fRemoteHost:$fRemotePort on remote side');

      /// Do the port forwarding for sshd
      final serverSocket = await ServerSocket.bind('localhost', fLocalPort);

      serverSocket.listen((socket) async {
        counter++;
        final forward = await client.forwardLocal(fRemoteHost, fRemotePort);
        unawaited(
          forward.stream.cast<List<int>>().pipe(socket).whenComplete(
            () async {
              counter--;
            },
          ),
        );
        unawaited(socket.pipe(forward.sink));
      }, onError: (Object error) {
        counter = 0;
      }, onDone: () {
        counter = 0;
      });
    }

    // Start local forwarding to the remote sshd
    await startForwarding(fLocalPort: localPort, fRemoteHost: 'localhost', fRemotePort: remoteSshdPort);

    if (addForwardsToTunnel) {
      var optionsSplitBySpace = localSshOptions.join(' ').split(' ');
      logger.info('addForwardsToTunnel is true;'
          ' localSshOptions split by space is $optionsSplitBySpace');
      // parse the localSshOptions, extract all of the local port forwarding
      // directives and act on all of them
      var lsoIter = optionsSplitBySpace.iterator;
      while (lsoIter.moveNext()) {
        if (lsoIter.current == '-L') {
          // we expect the args next
          bool hasArgs = lsoIter.moveNext();
          if (!hasArgs) {
            logger.warning('localSshOptions has -L with no args');
            continue;
          }
          String argString = lsoIter.current;
          // We expect args like $localPort:$remoteHost:$remotePort
          List<String> args = argString.split(':');
          if (args.length != 3) {
            logger.warning('localSshOptions has -L with bad args $argString');
            continue;
          }
          int? fLocalPort = int.tryParse(args[0]);
          String fRemoteHost = args[1];
          int? fRemotePort = int.tryParse(args[2]);
          if (fLocalPort == null || fRemoteHost.isEmpty || fRemotePort == null) {
            logger.warning('localSshOptions has -L with bad args $argString');
            continue;
          }

          // Start the forwarding
          await startForwarding(fLocalPort: fLocalPort, fRemoteHost: fRemoteHost, fRemotePort: fRemotePort);
        }
      }
    }

    /// Set up timer to check to see if all connections are down
    logger.info('ssh session will terminate after $idleTimeout seconds'
        ' if it is not being used');
    Timer.periodic(Duration(seconds: idleTimeout), (timer) async {
      if (counter == 0) {
        timer.cancel();
        client.close();
        await client.done;
        _doneCompleter.complete();
        logger.shout('$sessionId | no active connections'
            ' - ssh session complete');
      }
    });

    return (true, null, client);
  }

  Future<(bool, String?, Process?)> directSshViaExec() async {
    // If using exec then we can assume we're on something unix-y
    // So we can write the ephemeralPrivateKey to a tmp file,
    // set its permissions appropriately, and remove it after we've
    // executed the command
    var tmpFileName = '/tmp/ephemeral_$sessionId';
    File tmpFile = File(tmpFileName);
    await tmpFile.create(recursive: true);
    await tmpFile.writeAsString(ephemeralPrivateKey, mode: FileMode.write, flush: true);
    await Process.run('chmod', ['go-rwx', tmpFileName]);

    String argsString = '$remoteUsername@$host'
        ' -p $_sshrvdPort'
        ' -i $tmpFileName'
        ' -L $localPort:localhost:$remoteSshdPort'
        ' -o LogLevel=VERBOSE'
        ' -t -t'
        ' -o StrictHostKeyChecking=accept-new'
        ' -o IdentitiesOnly=yes'
        ' -o BatchMode=yes'
        ' -o ExitOnForwardFailure=yes'
        ' -f' // fork after authentication - this is important
        ;
    if (addForwardsToTunnel) {
      argsString += ' ${localSshOptions.join(' ')}';
    }
    argsString += ' sleep 15';

    List<String> args = argsString.split(' ');

    logger.info('$sessionId | Executing /usr/bin/ssh ${args.join(' ')}');

    // Because of the options we are using, we can wait for this process
    // to complete, because it will exit with exitCode 0 once it has connected
    // successfully
    late int sshExitCode;
    final soutBuf = StringBuffer();
    final serrBuf = StringBuffer();
    Process? process;
    try {
      process = await Process.start('/usr/bin/ssh', args);
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

    await tmpFile.delete();

    String? errorMessage;
    if (sshExitCode != 0) {
      if (sshExitCode == 6464) {
        logger.shout('$sessionId | Command timed out: /usr/bin/ssh ${args.join(' ')}');
        errorMessage = 'Failed to establish connection - timed out';
      } else {
        logger.shout('$sessionId | Exit code $sshExitCode from'
            ' /usr/bin/ssh ${args.join(' ')}');
        errorMessage = 'Failed to establish connection - exit code $sshExitCode';
      }
    }

    return (sshExitCode == 0, errorMessage, process);
  }

  /// Identical to [legacyStartReverseSsh] except for the request notification
  Future<SSHNPResult> startReverseSsh() async {
    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    SSHRV sshrv = sshrvGenerator(host, _sshrvdPort, localSshdPort: localSshdPort);
    Future sshrvResult = sshrv.run();

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
          'port': port,
          'username': username,
          'remoteForwardPort': localPort,
          'privateKey': sshPrivateKey
        }),
        sessionId: sessionId);

    bool acked = await waitForDaemonResponse();
    await cleanUpAfterReverseSsh(this);
    if (!acked) {
      return SSHNPFailed('sshnp connection timeout: waiting for daemon response');
    }

    if (sshnpdAckErrors) {
      return SSHNPFailed('sshnp failed: with sshnpd acknowledgement errors');
    }

    return SSHCommand.base(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
      localSshOptions: (addForwardsToTunnel) ? localSshOptions : null,
      sshrvResult: sshrvResult,
    );
  }

  Future<SSHNPResult> legacyStartReverseSsh() async {
    // Connect to rendezvous point using background process.
    // sshnp (this program) can then exit without issue.
    SSHRV sshrv = sshrvGenerator(host, _sshrvdPort, localSshdPort: localSshdPort);
    Future sshrvResult = sshrv.run();

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
      return SSHNPFailed('sshnp timed out: waiting for daemon response\nhint: make sure the device is online');
    }

    if (sshnpdAckErrors) {
      return SSHNPFailed('sshnp failed: with sshnpd acknowledgement errors');
    }

    return SSHCommand.base(
      localPort: localPort,
      remoteUsername: remoteUsername,
      host: 'localhost',
      privateKeyFileName: publicKeyFileName.replaceAll('.pub', ''),
      localSshOptions: (addForwardsToTunnel) ? localSshOptions : null,
      sshrvResult: sshrvResult,
    );
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

    bool connected = false;

    if (notification.value == 'connected') {
      connected = true;
    } else if (notification.value.startsWith('{')) {
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
        logger.warning('Failed to extract parameters from notification value "${notification.value}" with error : $e');
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
    AtKey userNameRecordID = AtKey.fromString('$clientAtSign:username.$namespace$sshnpdAtSign');
    try {
      remoteUsername = (await atClient.get(userNameRecordID)).value as String;
    } catch (e, s) {
      stderr.writeln("Device \"$device\" unknown, or username not shared");
      await cleanUpAfterReverseSsh(this);
      throw SSHNPFailed(
          "Device unknown, or username not shared\n"
          "hint: make sure the device shares username or set remote username manually",
          e,
          s);
    }
  }

  Future<void> sharePublicKeyWithSshnpdIfRequired() async {
    if (publicKeyFileName.isEmpty) return;

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
    } catch (e, s) {
      stderr.writeln("Error opening or validating public key file or sending to remote atSign: $e");
      await cleanUpAfterReverseSsh(this);
      throw SSHNPFailed('Error opening or validating public key file or sending to remote atSign', e, s);
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
        .subscribe(regex: '$sessionId.${SSHRVD.namespace}@', shouldDecrypt: true)
        .listen((notification) async {
      String ipPorts = notification.value.toString();
      List results = ipPorts.split(',');
      host = results[0];
      port = int.parse(results[1]);
      _sshrvdPort = int.parse(results[2]);
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
        throw ('Connection timeout to sshrvd $host service\nhint: make sure host is valid and online');
      }
    }
  }

  Future<List<AtKey>> _getAtKeysRemote(
      {String? regex, String? sharedBy, String? sharedWith, bool showHiddenKeys = false}) async {
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
          logger.severe('Exception occurred: ${e.toString()}. Unable to form key $key');
        }
      }).toList();
    }
    result.removeWhere((element) => element == null);
    return result.cast<AtKey>();
  }

  @override
  Future<(Iterable<String>, Iterable<String>, Map<String, dynamic>)> listDevices() async {
    // get all the keys device_info.*.sshnpd
    var scanRegex = 'device_info\\.$asciiMatcher\\.${SSHNPD.namespace}';

    var atKeys = await _getAtKeysRemote(regex: scanRegex, sharedBy: sshnpdAtSign);

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
  Future<void> _notify(AtKey atKey, String value, {String sessionId = ""}) async {
    await atClient.notificationService.notify(NotificationParams.forUpdate(atKey, value: value),
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
