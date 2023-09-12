part of 'sshnp.dart';

class SSHNPParams {
  /// Required Arguments
  /// These arguments do not have fallback values and must be provided.
  /// Since there are multiple sources for these values, we cannot validate
  /// that they will be provided. If any are null, then the caller must
  /// handle the error.
  final String? clientAtSign;
  final String? sshnpdAtSign;
  final String? host;

  /// Optional Arguments
  final String device;
  final int port;
  final int localPort;
  late final String username;
  late final String homeDirectory;
  late final String atKeysFilePath;
  late final String sendSshPublicKey;
  late final List<String> localSshOptions;
  late final bool rsa;
  late final String? remoteUsername;
  late final bool verbose;
  late final String rootDomain;
  late final int localSshdPort;
  late final bool legacyDaemon;
  late final int remoteSshdPort;
  late final int idleTimeout;
  late final String sshClient;
  late final bool addForwardsToTunnel;

  /// Special Arguments
  late final String? profileName; // automatically populated with the filename if from a configFile
  late final bool listDevices;

  SSHNPParams({
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.host,
    this.profileName,
    this.device = SSHNP.defaultDevice,
    this.port = SSHNP.defaultPort,
    this.localPort = SSHNP.defaultLocalPort,
    this.sendSshPublicKey = SSHNP.defaultSendSshPublicKey,
    this.localSshOptions = SSHNP.defaultLocalSshOptions,
    this.verbose = defaults.defaultVerbose,
    this.rsa = defaults.defaultRsa,
    this.remoteUsername,
    String? atKeysFilePath,
    this.rootDomain = defaults.defaultRootDomain,
    this.localSshdPort = defaults.defaultLocalSshdPort,
    this.legacyDaemon = SSHNP.defaultLegacyDaemon,
    this.listDevices = SSHNP.defaultListDevices,
    this.remoteSshdPort = defaults.defaultRemoteSshdPort,
    this.idleTimeout = defaults.defaultIdleTimeout,
    String? sshClient,
    this.addForwardsToTunnel = false,
  }) {
    // Do we have a username ?
    username = getUserName(throwIfNull: true)!;

    // Do we have a 'home' directory?
    homeDirectory = getHomeDirectory(throwIfNull: true)!;

    // Use default atKeysFilePath if not provided

    this.atKeysFilePath = atKeysFilePath ?? getDefaultAtKeysFilePath(homeDirectory, clientAtSign);

    this.sshClient = sshClient ?? SSHNP.defaultSshClient.cliArg;
  }

  factory SSHNPParams.empty() {
    return SSHNPParams(
      profileName: '',
      clientAtSign: '',
      sshnpdAtSign: '',
      host: '',
    );
  }

  factory SSHNPParams.fromFile(String fileName) {
    return SSHNPParams.fromPartial(SSHNPPartialParams.fromFile(fileName));
  }

  factory SSHNPParams.fromJson(String json) => SSHNPParams.fromPartial(SSHNPPartialParams.fromJson(json));

  factory SSHNPParams.fromPartial(SSHNPPartialParams partial) {
    AtSignLogger logger = AtSignLogger(' SSHNPParams ');

    /// If any required params are null log severe, but do not throw
    /// The caller must handle the error if any required params are null
    partial.clientAtSign ?? (logger.severe('clientAtSign is null'));
    partial.sshnpdAtSign ?? (logger.severe('sshnpdAtSign is null'));
    partial.host ?? (logger.severe('host is null'));

    return SSHNPParams(
      profileName: partial.profileName,
      clientAtSign: partial.clientAtSign,
      sshnpdAtSign: partial.sshnpdAtSign,
      host: partial.host,
      device: partial.device ?? SSHNP.defaultDevice,
      port: partial.port ?? SSHNP.defaultPort,
      localPort: partial.localPort ?? SSHNP.defaultLocalPort,
      sendSshPublicKey: partial.sendSshPublicKey ?? SSHNP.defaultSendSshPublicKey,
      localSshOptions: partial.localSshOptions,
      rsa: partial.rsa ?? defaults.defaultRsa,
      verbose: partial.verbose ?? defaults.defaultVerbose,
      remoteUsername: partial.remoteUsername,
      atKeysFilePath: partial.atKeysFilePath,
      rootDomain: partial.rootDomain ?? defaults.defaultRootDomain,
      localSshdPort: partial.localSshdPort ?? defaults.defaultLocalSshdPort,
      listDevices: partial.listDevices,
      legacyDaemon: partial.legacyDaemon ?? SSHNP.defaultLegacyDaemon,
      remoteSshdPort: partial.remoteSshdPort ?? defaults.defaultRemoteSshdPort,
      idleTimeout: partial.idleTimeout ?? defaults.defaultIdleTimeout,
      sshClient: partial.sshClient ?? SSHNP.defaultSshClient.cliArg,
      addForwardsToTunnel: partial.addForwardsToTunnel ?? false,
    );
  }

  factory SSHNPParams.fromConfigFile(String fileName) {
    return SSHNPParams.fromPartial(SSHNPPartialParams.fromConfig(fileName));
  }

  static Future<Iterable<SSHNPParams>> getConfigFilesFromDirectory([String? directory]) async {
    var params = <SSHNPParams>[];

    var homeDirectory = getHomeDirectory(throwIfNull: true)!;
    directory ??= getDefaultSshnpConfigDirectory(homeDirectory);
    var files = Directory(directory).list();

    await files.forEach((file) {
      if (file is! File) return;
      if (path.extension(file.path) != '.env') return;
      try {
        var p = SSHNPParams.fromConfigFile(file.path);

        params.add(p);
      } catch (e) {
        print('Error reading config file: ${file.path}');
        print(e);
      }
    });

    return params;
  }

  Future<File> toFile({String? directory, bool overwrite = false}) async {
    if (profileName == null || profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName = profileName!.replaceAll(' ', '_');

    var file = File(path.join(
      directory ?? getDefaultSshnpConfigDirectory(homeDirectory),
      '$fileName.env',
    ));

    var exists = await file.exists();

    if (exists && !overwrite) {
      throw Exception('Failed to write config file: ${file.path} already exists');
    }

    // FileMode.write will create the file if it does not exist
    // and overwrite existing files if it does exist
    return file.writeAsString(toConfig(), mode: FileMode.write);
  }

  Future<FileSystemEntity> deleteFile({String? directory, bool overwrite = false}) async {
    if (profileName == null || profileName!.isEmpty) {
      throw Exception('profileName is null or empty');
    }

    var fileName = profileName!.replaceAll(' ', '_');

    var file = File(path.join(
      directory ?? getDefaultSshnpConfigDirectory(homeDirectory),
      '$fileName.env',
    ));

    var exists = await file.exists();

    if (!exists) {
      throw Exception('Cannot delete ${file.path}, file does not exist');
    }

    return file.delete();
  }

  Map<String, dynamic> toArgs() {
    return {
      'profile-name': profileName,
      'from': clientAtSign,
      'to': sshnpdAtSign,
      'host': host,
      'device': device,
      'port': port,
      'local-port': localPort,
      'key-file': atKeysFilePath,
      'ssh-public-key': sendSshPublicKey,
      'local-ssh-options': localSshOptions,
      'rsa': rsa,
      'remote-user-name': remoteUsername,
      'verbose': verbose,
      'root-domain': rootDomain,
      'local-sshd-port': localSshdPort,
      'remote-sshd-port': remoteSshdPort,
      'idle-timeout': idleTimeout,
      'ssh-client': sshClient,
      'add-forwards-to-tunnel': addForwardsToTunnel,
    };
  }

  String toConfig() {
    var lines = <String>[];
    for (var entry in toArgs().entries) {
      var key = SSHNPArg.fromName(entry.key).bashName;
      if (key.isEmpty) continue;
      var value = entry.value;
      if (value == null) continue;
      if (value is List) {
        value = value.join(',');
      }
      lines.add('$key=$value');
    }
    return lines.join('\n');
  }

  String toJson() {
    return jsonEncode(toArgs());
  }
}

/// A class which contains a subset of the SSHNPParams
/// This may be used when part of the params come from separate sources
/// e.g. default values from a config file and the rest from the command line
class SSHNPPartialParams {
  // Non param variables
  static final ArgParser parser = createArgParser();

  /// Main Params
  late final String? profileName;
  late final String? clientAtSign;
  late final String? sshnpdAtSign;
  late final String? host;
  late final String? device;
  late final int? port;
  late final int? localPort;
  late final int? localSshdPort;
  late final String? atKeysFilePath;
  late final String? sendSshPublicKey;
  late final List<String>? localSshOptions;
  late final bool? rsa;
  late final String? remoteUsername;
  late final bool? verbose;
  late final String? rootDomain;
  late final bool? legacyDaemon;
  late final int? remoteSshdPort;
  late final int? idleTimeout;
  late final String? sshClient;
  late final bool? addForwardsToTunnel;

  /// Special Params
  // N.B. config file is a meta param and doesn't need to be included
  final bool? listDevices;

  SSHNPPartialParams({
    this.profileName,
    this.clientAtSign,
    this.sshnpdAtSign,
    this.host,
    this.device,
    this.port,
    this.localPort,
    this.atKeysFilePath,
    this.sendSshPublicKey,
    this.localSshOptions,
    this.rsa,
    this.remoteUsername,
    this.verbose,
    this.rootDomain,
    this.localSshdPort,
    this.listDevices = SSHNP.defaultListDevices,
    this.legacyDaemon = SSHNP.defaultLegacyDaemon,
    this.remoteSshdPort,
    this.idleTimeout,
    this.sshClient,
    this.addForwardsToTunnel,
  });

  factory SSHNPPartialParams.empty() {
    return SSHNPPartialParams();
  }

  /// Merge two SSHNPPartialParams objects together
  /// Params in params2 take precedence over params1
  /// - localSshOptions are concatenated together as (params1 + params2)
  factory SSHNPPartialParams.merge(SSHNPPartialParams params1, [SSHNPPartialParams? params2]) {
    params2 ??= SSHNPPartialParams.empty();
    return SSHNPPartialParams(
      profileName: params2.profileName ?? params1.profileName,
      clientAtSign: params2.clientAtSign ?? params1.clientAtSign,
      sshnpdAtSign: params2.sshnpdAtSign ?? params1.sshnpdAtSign,
      host: params2.host ?? params1.host,
      device: params2.device ?? params1.device,
      port: params2.port ?? params1.port,
      localPort: params2.localPort ?? params1.localPort,
      atKeysFilePath: params2.atKeysFilePath ?? params1.atKeysFilePath,
      sendSshPublicKey: params2.sendSshPublicKey ?? params1.sendSshPublicKey,
      localSshOptions: params2.localSshOptions ?? params1.localSshOptions,
      rsa: params2.rsa ?? params1.rsa,
      remoteUsername: params2.remoteUsername ?? params1.remoteUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      localSshdPort: params2.localSshdPort ?? params1.localSshdPort,
      listDevices: params2.listDevices || params1.listDevices,
      legacyDaemon: params2.legacyDaemon ?? params1.legacyDaemon,
      remoteSshdPort: params2.remoteSshdPort ?? params1.remoteSshdPort,
      idleTimeout: params2.idleTimeout ?? params1.idleTimeout,
      sshClient: params2.sshClient ?? params1.sshClient,
      addForwardsToTunnel: params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
    );
  }

  factory SSHNPPartialParams.fromFile(String fileName) {
    var args = ConfigFileRepository.parseConfigFile(fileName);
    args['profile-name'] = ConfigFileRepository.toProfileName(fileName);
    return SSHNPPartialParams.fromMap(args);
  }

  factory SSHNPPartialParams.fromJson(String json) => SSHNPPartialParams.fromMap(jsonDecode(json));

  factory SSHNPPartialParams.fromMap(Map<String, dynamic> args) {
    return SSHNPPartialParams(
      profileName: args['profile-name'],
      clientAtSign: args['from'],
      sshnpdAtSign: args['to'],
      host: args['host'],
      device: args['device'],
      port: args['port'],
      localPort: args['local-port'],
      atKeysFilePath: args['key-file'],
      sendSshPublicKey: args['ssh-public-key'],
      localSshOptions: args['local-ssh-options'] ?? SSHNP.defaultLocalSshOptions,
      rsa: args['rsa'],
      remoteUsername: args['remote-user-name'],
      verbose: args['verbose'],
      rootDomain: args['root-domain'],
      localSshdPort: args['local-sshd-port'],
      listDevices: args['list-devices'] ?? SSHNP.defaultListDevices,
      legacyDaemon: args['legacy-daemon'],
      remoteSshdPort: args['remote-sshd-port'],
      idleTimeout: args['idle-timeout'],
      sshClient: args['ssh-client'],
      addForwardsToTunnel: args['add-forwards-to-tunnel'],
    );
  }

  factory SSHNPPartialParams.fromConfig(String fileName) {
    var args = _parseConfigFile(fileName);
    args['profile-name'] = path.basenameWithoutExtension(fileName).replaceAll('_', ' ');
    return SSHNPPartialParams.fromMap(args);
  }

  /// Parses args from command line
  /// first merges from a config file if provided via --config-file
  factory SSHNPPartialParams.fromArgs(List<String> args) {
    var params = SSHNPPartialParams.empty();

    var parsedArgs = _createArgParser(withDefaults: false).parse(args);

    if (parsedArgs.wasParsed('config-file')) {
      var configFileName = parsedArgs['config-file'] as String;
      params = SSHNPPartialParams.merge(
        params,
        SSHNPPartialParams.fromConfig(configFileName),
      );
    }

    // THIS IS A WORKAROUND IN ORDER TO BE TYPE SAFE IN SSHNPPartialParams.fromArgMap
    Map<String, dynamic> parsedArgsMap = {
      for (var e in parsedArgs.options)
        e: SSHNPArg.fromName(e).type == ArgType.integer ? int.tryParse(parsedArgs[e]) : parsedArgs[e]
    };

    return SSHNPPartialParams.merge(
      params,
      SSHNPPartialParams.fromArgMap(parsedArgsMap),
    );
  }

  static ArgParser _createArgParser({
    bool withConfig = true,
    bool withDefaults = true,
    bool withListDevices = true,
  }) {
    var parser = ArgParser();
    // Basic arguments
    for (SSHNPArg arg in SSHNPArg.args) {
      switch (arg.format) {
        case ArgFormat.option:
          parser.addOption(
            arg.name,
            abbr: arg.abbr,
            mandatory: arg.mandatory,
            defaultsTo: withDefaults ? arg.defaultsTo?.toString() : null,
            allowed: arg.allowed,
            help: arg.help,
          );
          break;
        case ArgFormat.multiOption:
          parser.addMultiOption(
            arg.name,
            abbr: arg.abbr,
            defaultsTo: withDefaults ? arg.defaultsTo as List<String>? : null,
            allowed: arg.allowed,
            help: arg.help,
          );
          break;
        case ArgFormat.flag:
          parser.addFlag(
            arg.name,
            abbr: arg.abbr,
            defaultsTo: withDefaults ? arg.defaultsTo as bool? : null,
            help: arg.help,
          );
          break;
      }
    }
    if (withConfig) {
      parser.addOption(
        'config-file',
        help: 'Read args from a config file\nMandatory args are not required if already supplied in the config file',
      );
    }
    if (withListDevices) {
      parser.addFlag(
        'list-devices',
        aliases: ['ls'],
        negatable: false,
        help: 'List available devices',
      );
    }
    return parser;
  }

  static Map<String, dynamic> _parseConfigFile(String fileName) {
    Map<String, dynamic> args = <String, dynamic>{};

    File file = File(fileName);

    if (!file.existsSync()) {
      throw Exception('Config file does not exist: $fileName');
    }
    try {
      List<String> lines = file.readAsLinesSync();

      for (String line in lines) {
        if (line.startsWith('#')) continue;

        var parts = line.split('=');
        if (parts.length != 2) continue;

        var key = parts[0].trim();
        var value = parts[1].trim();

        SSHNPArg arg = SSHNPArg.fromBashName(key);
        if (arg.name.isEmpty) continue;

        switch (arg.format) {
          case ArgFormat.flag:
            if (value.toLowerCase() == 'true') {
              args[arg.name] = true;
            }
            continue;
          case ArgFormat.multiOption:
            var values = value.split(',');
            args.putIfAbsent(arg.name, () => <String>[]);
            for (String val in values) {
              if (val.isEmpty) continue;
              args[arg.name].add(val);
            }
            continue;
          case ArgFormat.option:
            if (value.isEmpty) continue;
            if (arg.type == ArgType.integer) {
              args[arg.name] = int.tryParse(value);
            } else {
              args[arg.name] = value;
            }
            continue;
        }
      }
      return args;
    } on FileSystemException {
      throw Exception('Error reading config file: $fileName');
    } catch (e) {
      throw Exception('Error parsing config file: $fileName');
    }
  }
}
