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
  final String sendSshPublicKey;
  final List<String> localSshOptions;
  final bool rsa;
  final String? remoteUsername;
  final bool verbose;
  final String rootDomain;
  final int localSshdPort;
  final bool legacyDaemon;

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
    this.verbose = SSHNP.defaultVerbose,
    this.rsa = SSHNP.defaultRsa,
    this.remoteUsername,
    String? atKeysFilePath,
    this.rootDomain = SSHNP.defaultRootDomain,
    this.localSshdPort = SSHNP.defaultLocalSshdPort,
    this.legacyDaemon = SSHNP.defaultLegacyDaemon,
    this.listDevices = SSHNP.defaultListDevices,
  }) {
    // Do we have a username ?
    username = getUserName(throwIfNull: true)!;

    // Do we have a 'home' directory?
    homeDirectory = getHomeDirectory(throwIfNull: true)!;

    // Use default atKeysFilePath if not provided

    this.atKeysFilePath = atKeysFilePath ?? getDefaultAtKeysFilePath(homeDirectory, clientAtSign);
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
      localSshOptions: partial.localSshOptions ?? SSHNP.defaultLocalSshOptions,
      rsa: partial.rsa ?? SSHNP.defaultRsa,
      verbose: partial.verbose ?? SSHNP.defaultRsa,
      remoteUsername: partial.remoteUsername,
      atKeysFilePath: partial.atKeysFilePath,
      rootDomain: partial.rootDomain ?? SSHNP.defaultRootDomain,
      localSshdPort: partial.localSshdPort ?? SSHNP.defaultLocalSshdPort,
      listDevices: partial.listDevices ?? SSHNP.defaultListDevices,
      legacyDaemon: partial.legacyDaemon ?? SSHNP.defaultLegacyDaemon,
    );
  }

  factory SSHNPParams.merge(SSHNPParams params1, [SSHNPPartialParams? params2]) {
    params2 ??= SSHNPPartialParams.empty();
    return SSHNPParams(
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
      listDevices: params2.listDevices ?? params1.listDevices,
      legacyDaemon: params2.legacyDaemon ?? params1.legacyDaemon,
    );
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
      'local-sshd-port': localSshdPort
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
  final String? profileName;
  final String? clientAtSign;
  final String? sshnpdAtSign;
  final String? host;
  final String? device;
  final int? port;
  final int? localPort;
  final int? localSshdPort;
  final String? atKeysFilePath;
  final String? sendSshPublicKey;
  final List<String>? localSshOptions;
  final bool? rsa;
  final String? remoteUsername;
  final bool? verbose;
  final String? rootDomain;

  final bool? legacyDaemon;

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
    this.listDevices,
    this.legacyDaemon,
  });

  factory SSHNPPartialParams.empty() {
    return SSHNPPartialParams();
  }

  /// Parses args from command line
  /// first merges from a config file if provided via --config-file
  factory SSHNPPartialParams.fromArgs(List<String> args) {
    var params = SSHNPPartialParams.empty();

    var parsedArgs = createArgParser(withDefaults: false).parse(args);

    if (parsedArgs.wasParsed('config-file')) {
      var configFileName = parsedArgs['config-file'] as String;
      params = SSHNPPartialParams.merge(
        params,
        SSHNPPartialParams.fromFile(configFileName),
      );
    }

    // THIS IS A WORKAROUND IN ORDER TO BE TYPE SAFE IN SSHNPPartialParams.fromArgMap
    Map<String, dynamic> parsedArgsMap = {
      for (var e in parsedArgs.options)
        e: SSHNPArg.fromName(e).type == ArgType.integer ? int.tryParse(parsedArgs[e]) : parsedArgs[e]
    };

    return SSHNPPartialParams.merge(
      params,
      SSHNPPartialParams.fromMap(parsedArgsMap),
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
    );
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
      listDevices: params2.listDevices ?? params1.listDevices,
      legacyDaemon: params2.legacyDaemon ?? params1.legacyDaemon,
    );
  }
}
