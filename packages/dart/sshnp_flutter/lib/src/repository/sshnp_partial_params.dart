/// A class which contains a subset of the SshnpParams
/// This may be used when part of the params come from separate sources
/// e.g. default values from a config file and the rest from the command line
class SshnpPartialParams {
  /// Main Params
  final String? profileName;
  final String? clientAtSign;
  final String? sshnpdAtSign;
  final String? srvdAtSign;
  final String? device;
  final int? localPort;
  final String? atKeysFilePath;
  final String? identityFile;
  final String? identityPassphrase;
  final bool? sendSshPublicKey;
  final List<String>? localSshOptions;
  final String? remoteUsername;
  final String? tunnelUsername;
  final bool? verbose;
  final String? rootDomain;
  final int? remoteSshdPort;
  final int? idleTimeout;
  final bool? addForwardsToTunnel;
  final SupportedSshAlgorithm? sshAlgorithm;
  final bool? authenticateClientToRvd;
  final bool? authenticateDeviceToRvd;
  final bool? encryptRvdTraffic;
  final Duration? daemonPingTimeout;

  /// Operation flags
  final bool? listDevices;

  SshnpPartialParams({
    this.profileName,
    this.clientAtSign,
    this.sshnpdAtSign,
    this.srvdAtSign,
    this.device,
    this.localPort,
    this.atKeysFilePath,
    this.identityFile,
    this.identityPassphrase,
    this.sendSshPublicKey,
    this.localSshOptions,
    this.remoteUsername,
    this.tunnelUsername,
    this.verbose,
    this.rootDomain,
    this.listDevices,
    this.remoteSshdPort,
    this.idleTimeout,
    this.addForwardsToTunnel,
    this.sshAlgorithm,
    this.authenticateClientToRvd,
    this.authenticateDeviceToRvd,
    this.encryptRvdTraffic,
    this.daemonPingTimeout,
  });

  factory SshnpPartialParams.empty() {
    return SshnpPartialParams();
  }

  /// Merge two SshnpPartialParams objects together
  /// Params in params2 take precedence over params1
  factory SshnpPartialParams.merge(SshnpPartialParams params1,
      [SshnpPartialParams? params2]) {
    params2 ??= SshnpPartialParams.empty();
    return SshnpPartialParams(
      profileName: params2.profileName ?? params1.profileName,
      clientAtSign: params2.clientAtSign ?? params1.clientAtSign,
      sshnpdAtSign: params2.sshnpdAtSign ?? params1.sshnpdAtSign,
      srvdAtSign: params2.srvdAtSign ?? params1.srvdAtSign,
      device: params2.device ?? params1.device,
      localPort: params2.localPort ?? params1.localPort,
      atKeysFilePath: params2.atKeysFilePath ?? params1.atKeysFilePath,
      identityFile: params2.identityFile ?? params1.identityFile,
      identityPassphrase:
          params2.identityPassphrase ?? params1.identityPassphrase,
      sendSshPublicKey: params2.sendSshPublicKey ?? params1.sendSshPublicKey,
      localSshOptions: params2.localSshOptions ?? params1.localSshOptions,
      remoteUsername: params2.remoteUsername ?? params1.remoteUsername,
      tunnelUsername: params2.tunnelUsername ?? params1.tunnelUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      listDevices: params2.listDevices ?? params1.listDevices,
      remoteSshdPort: params2.remoteSshdPort ?? params1.remoteSshdPort,
      idleTimeout: params2.idleTimeout ?? params1.idleTimeout,
      addForwardsToTunnel:
          params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
      sshAlgorithm: params2.sshAlgorithm ?? params1.sshAlgorithm,
      authenticateClientToRvd:
          params2.authenticateClientToRvd ?? params1.authenticateClientToRvd,
      authenticateDeviceToRvd:
          params2.authenticateDeviceToRvd ?? params1.authenticateDeviceToRvd,
      encryptRvdTraffic: params2.encryptRvdTraffic ?? params1.encryptRvdTraffic,
      daemonPingTimeout: params2.daemonPingTimeout ?? params1.daemonPingTimeout,
    );
  }

  factory SshnpPartialParams.fromFile(String fileName) {
    var args = ConfigFileRepository.parseConfigFile(fileName);
    args[SshnpArg.profileNameArg.name] =
        ConfigFileRepository.toProfileName(fileName);
    return SshnpPartialParams.fromArgMap(args);
  }

  factory SshnpPartialParams.fromConfigLines(
      String profileName, List<String> lines) {
    var args = ConfigFileRepository.parseConfigFileContents(lines);
    args[SshnpArg.profileNameArg.name] = profileName;
    return SshnpPartialParams.fromArgMap(args);
  }

  factory SshnpPartialParams.fromJson(String json) =>
      SshnpPartialParams.fromArgMap(jsonDecode(json));

  factory SshnpPartialParams.fromArgMap(Map<String, dynamic> args) {
    return SshnpPartialParams(
      profileName: args[SshnpArg.profileNameArg.name],
      clientAtSign: args[SshnpArg.fromArg.name] == null
          ? null
          : AtUtils.fixAtSign(args[SshnpArg.fromArg.name]),
      sshnpdAtSign: args[SshnpArg.toArg.name] == null
          ? null
          : AtUtils.fixAtSign(args[SshnpArg.toArg.name]),
      srvdAtSign:
          args[SshnpArg.srvdArg.name] ?? args[SshnpArg.legacySrvdArg.name],
      device: args[SshnpArg.deviceArg.name],
      localPort: args[SshnpArg.localPortArg.name],
      atKeysFilePath: args[SshnpArg.keyFileArg.name],
      identityFile: args[SshnpArg.identityFileArg.name],
      identityPassphrase: args[SshnpArg.identityPassphraseArg.name],
      sendSshPublicKey: args[SshnpArg.sendSshPublicKeyArg.name],
      localSshOptions: args[SshnpArg.localSshOptionsArg.name] == null
          ? null
          : List<String>.from(args[SshnpArg.localSshOptionsArg.name]),
      remoteUsername: args[SshnpArg.remoteUserNameArg.name],
      tunnelUsername: args[SshnpArg.tunnelUserNameArg.name],
      verbose: args[SshnpArg.verboseArg.name],
      rootDomain: args[SshnpArg.rootDomainArg.name],
      listDevices: args[SshnpArg.listDevicesArg.name],
      remoteSshdPort: args[SshnpArg.remoteSshdPortArg.name],
      idleTimeout: args[SshnpArg.idleTimeoutArg.name],
      addForwardsToTunnel: args[SshnpArg.addForwardsToTunnelArg.name],
      sshAlgorithm: args[SshnpArg.sshAlgorithmArg.name] == null
          ? null
          : SupportedSshAlgorithm.fromString(
              args[SshnpArg.sshAlgorithmArg.name]),
      authenticateClientToRvd: args[SshnpArg.authenticateClientToRvdArg.name],
      authenticateDeviceToRvd: args[SshnpArg.authenticateDeviceToRvdArg.name],
      encryptRvdTraffic: args[SshnpArg.encryptRvdTrafficArg.name],
      daemonPingTimeout: Duration(
          seconds: args[SshnpArg.daemonPingTimeoutArg.name] ??
              DefaultArgs.daemonPingTimeoutSeconds),
    );
  }

  /// Parses args from command line
  /// first merges from a config file if provided via --config-file
  factory SshnpPartialParams.fromArgList(List<String> args,
      {ParserType parserType = ParserType.all}) {
    var params = SshnpPartialParams.empty();
    var parser = SshnpArg.createArgParser(
      withDefaults: false,
      parserType: parserType,
    );
    var parsedArgs = parser.parse(args);
    if (parser.options.keys.contains(SshnpArg.configFileArg.name) &&
        parsedArgs.wasParsed(SshnpArg.configFileArg.name)) {
      var configFileName = parsedArgs[SshnpArg.configFileArg.name] as String;
      params = SshnpPartialParams.merge(
        params,
        SshnpPartialParams.fromFile(configFileName),
      );
    }

    // THIS IS A WORKAROUND IN ORDER TO BE TYPE SAFE IN SshnpPartialParams.fromArgMap
    Map<String, dynamic> parsedArgsMap = {};
    for (var e in parsedArgs.options) {
      SshnpArg arg = SshnpArg.fromName(e);
      try {
        final v = arg.type == ArgType.integer
            ? int.parse(parsedArgs[e])
            : parsedArgs[e];
        parsedArgsMap[e] = v;
      } on FormatException catch (_) {
        var msg = 'Invalid value "${parsedArgs[e]}" for option --${arg.name}';
        if (arg.abbr != null) {
          msg += ' (-${arg.abbr})';
        }
        throw ArgumentError(msg);
      }
    }

    if (parsedArgs.rest.isNotEmpty) {
      throw ArgumentError("Unparsed args ${parsedArgs.rest}");
    }

    return SshnpPartialParams.merge(
      params,
      SshnpPartialParams.fromArgMap(parsedArgsMap),
    );
  }
}
