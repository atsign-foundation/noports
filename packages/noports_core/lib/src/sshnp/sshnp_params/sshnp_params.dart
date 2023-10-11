import 'dart:convert';

import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnp/sshnp_params/config_file_repository.dart';
import 'package:noports_core/src/sshnp/sshnp_params/sshnp_arg.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/sshnp.dart';

class SSHNPParams {
  /// Required Arguments
  /// These arguments do not have fallback values and must be provided.
  /// Since there are multiple sources for these values, we cannot validate
  /// that they will be provided. If any are null, then the caller must
  /// handle the error.
  final String clientAtSign;
  final String sshnpdAtSign;
  final String host;

  /// Optional Arguments
  final String device;
  final int port;
  final int localPort;
  final String? identityFile;
  final String? identityPassphrase;
  final bool sendSshPublicKey;
  final List<String> localSshOptions;
  final String? remoteUsername;
  final bool verbose;
  final String rootDomain;
  final int localSshdPort;
  final bool legacyDaemon;
  final int remoteSshdPort;
  final int idleTimeout;
  final bool addForwardsToTunnel;
  final String? atKeysFilePath;
  final SupportedSshClient sshClient;
  final SupportedSSHAlgorithm sshAlgorithm;

  /// Special Arguments
  final String? profileName; // automatically populated with the filename if from a configFile

  /// Operation flags
  final bool listDevices;

  SSHNPParams({
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.host,
    this.profileName,
    this.device = DefaultSSHNPArgs.device,
    this.port = DefaultSSHNPArgs.port,
    this.localPort = DefaultSSHNPArgs.localPort,
    this.identityFile,
    this.identityPassphrase,
    this.sendSshPublicKey = DefaultSSHNPArgs.sendSshPublicKey,
    this.localSshOptions = DefaultSSHNPArgs.localSshOptions,
    this.verbose = DefaultArgs.verbose,
    this.remoteUsername,
    this.atKeysFilePath,
    this.rootDomain = DefaultArgs.rootDomain,
    this.localSshdPort = DefaultArgs.localSshdPort,
    this.legacyDaemon = DefaultSSHNPArgs.legacyDaemon,
    this.listDevices = DefaultSSHNPArgs.listDevices,
    this.remoteSshdPort = DefaultArgs.remoteSshdPort,
    this.idleTimeout = DefaultArgs.idleTimeout,
    this.addForwardsToTunnel = DefaultArgs.addForwardsToTunnel,
    this.sshClient = DefaultSSHNPArgs.sshClient,
    this.sshAlgorithm = DefaultArgs.sshAlgorithm,
  });

  factory SSHNPParams.empty() {
    return SSHNPParams(
      profileName: '',
      clientAtSign: '',
      sshnpdAtSign: '',
      host: '',
    );
  }

  /// Merge an SSHNPPartialParams objects into an SSHNPParams
  /// Params in params2 take precedence over params1
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
      identityFile: params2.identityFile ?? params1.identityFile,
      identityPassphrase: params2.identityPassphrase ?? params1.identityPassphrase,
      sendSshPublicKey: params2.sendSshPublicKey ?? params1.sendSshPublicKey,
      localSshOptions: params2.localSshOptions ?? params1.localSshOptions,
      remoteUsername: params2.remoteUsername ?? params1.remoteUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      localSshdPort: params2.localSshdPort ?? params1.localSshdPort,
      listDevices: params2.listDevices ?? params1.listDevices,
      legacyDaemon: params2.legacyDaemon ?? params1.legacyDaemon,
      remoteSshdPort: params2.remoteSshdPort ?? params1.remoteSshdPort,
      idleTimeout: params2.idleTimeout ?? params1.idleTimeout,
      addForwardsToTunnel: params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
      sshClient: params2.sshClient ?? params1.sshClient,
      sshAlgorithm: params2.sshAlgorithm ?? params1.sshAlgorithm,
    );
  }

  factory SSHNPParams.fromFile(String fileName) {
    return SSHNPParams.fromPartial(SSHNPPartialParams.fromFile(fileName));
  }

  factory SSHNPParams.fromJson(String json) => SSHNPParams.fromPartial(SSHNPPartialParams.fromJson(json));

  factory SSHNPParams.fromPartial(SSHNPPartialParams partial) {
    partial.clientAtSign ?? (throw ArgumentError('from is mandatory'));
    partial.sshnpdAtSign ?? (throw ArgumentError('to is mandatory'));
    partial.host ?? (throw ArgumentError('host is mandatory'));
    return SSHNPParams(
      profileName: partial.profileName,
      clientAtSign: partial.clientAtSign!,
      sshnpdAtSign: partial.sshnpdAtSign!,
      host: partial.host!,
      device: partial.device ?? DefaultSSHNPArgs.device,
      port: partial.port ?? DefaultSSHNPArgs.port,
      localPort: partial.localPort ?? DefaultSSHNPArgs.localPort,
      identityFile: partial.identityFile,
      identityPassphrase: partial.identityPassphrase,
      sendSshPublicKey: partial.sendSshPublicKey ?? DefaultSSHNPArgs.sendSshPublicKey,
      localSshOptions: partial.localSshOptions ?? DefaultSSHNPArgs.localSshOptions,
      verbose: partial.verbose ?? DefaultArgs.verbose,
      remoteUsername: partial.remoteUsername,
      atKeysFilePath: partial.atKeysFilePath,
      rootDomain: partial.rootDomain ?? DefaultArgs.rootDomain,
      localSshdPort: partial.localSshdPort ?? DefaultArgs.localSshdPort,
      listDevices: partial.listDevices ?? DefaultSSHNPArgs.listDevices,
      legacyDaemon: partial.legacyDaemon ?? DefaultSSHNPArgs.legacyDaemon,
      remoteSshdPort: partial.remoteSshdPort ?? DefaultArgs.remoteSshdPort,
      idleTimeout: partial.idleTimeout ?? DefaultArgs.idleTimeout,
      addForwardsToTunnel: partial.addForwardsToTunnel ?? DefaultArgs.addForwardsToTunnel,
      sshClient: partial.sshClient ?? DefaultSSHNPArgs.sshClient,
      sshAlgorithm: partial.sshAlgorithm ?? DefaultArgs.sshAlgorithm,
    );
  }

  factory SSHNPParams.fromConfigLines(String profileName, List<String> lines) {
    return SSHNPParams.fromPartial(SSHNPPartialParams.fromConfigLines(profileName, lines));
  }

  List<String> toConfigLines({ParserType parserType = ParserType.configFile}) {
    var lines = <String>[];
    for (var entry in toArgMap().entries) {
      var arg = SSHNPArg.fromName(entry.key);
      if (!parserType.shouldParse(arg.parseWhen)) continue;
      var key = arg.bashName;
      if (key.isEmpty) continue;
      var value = entry.value;
      if (value == null) continue;
      if (value is List) {
        value = value.join(',');
      }
      lines.add('$key=$value');
    }
    return lines;
  }

  Map<String, dynamic> toArgMap({ParserType parserType = ParserType.all}) {
    var args = {
      SSHNPArg.profileNameArg.name: profileName,
      SSHNPArg.fromArg.name: clientAtSign,
      SSHNPArg.toArg.name: sshnpdAtSign,
      SSHNPArg.hostArg.name: host,
      SSHNPArg.deviceArg.name: device,
      SSHNPArg.portArg.name: port,
      SSHNPArg.localPortArg.name: localPort,
      SSHNPArg.keyFileArg.name: atKeysFilePath,
      SSHNPArg.identityFileArg.name: identityFile,
      SSHNPArg.identityPassphraseArg.name: identityPassphrase,
      SSHNPArg.sendSshPublicKeyArg.name: sendSshPublicKey,
      SSHNPArg.localSshOptionsArg.name: localSshOptions,
      SSHNPArg.remoteUserNameArg.name: remoteUsername,
      SSHNPArg.verboseArg.name: verbose,
      SSHNPArg.rootDomainArg.name: rootDomain,
      SSHNPArg.localSshdPortArg.name: localSshdPort,
      SSHNPArg.remoteSshdPortArg.name: remoteSshdPort,
      SSHNPArg.idleTimeoutArg.name: idleTimeout,
      SSHNPArg.addForwardsToTunnelArg.name: addForwardsToTunnel,
      SSHNPArg.sshClientArg.name: sshClient.toString(),
      SSHNPArg.ssHAlgorithmArg.name: sshAlgorithm.toString(),
    };
    args.removeWhere(
      (key, value) => !parserType.shouldParse(SSHNPArg.fromName(key).parseWhen),
    );
    return args;
  }

  String toJson({ParserType parserType = ParserType.all}) {
    return jsonEncode(toArgMap(parserType: parserType));
  }
}

/// A class which contains a subset of the SSHNPParams
/// This may be used when part of the params come from separate sources
/// e.g. default values from a config file and the rest from the command line
class SSHNPPartialParams {
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
  final String? identityFile;
  final String? identityPassphrase;
  final bool? sendSshPublicKey;
  final List<String>? localSshOptions;
  final String? remoteUsername;
  final bool? verbose;
  final String? rootDomain;
  final bool? legacyDaemon;
  final int? remoteSshdPort;
  final int? idleTimeout;
  final bool? addForwardsToTunnel;
  final SupportedSshClient? sshClient;
  final SupportedSSHAlgorithm? sshAlgorithm;

  /// Operation flags
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
    this.identityFile,
    this.identityPassphrase,
    this.sendSshPublicKey,
    this.localSshOptions,
    this.remoteUsername,
    this.verbose,
    this.rootDomain,
    this.localSshdPort,
    this.listDevices,
    this.legacyDaemon,
    this.remoteSshdPort,
    this.idleTimeout,
    this.addForwardsToTunnel,
    this.sshClient,
    this.sshAlgorithm,
  });

  factory SSHNPPartialParams.empty() {
    return SSHNPPartialParams();
  }

  /// Merge two SSHNPPartialParams objects together
  /// Params in params2 take precedence over params1
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
      identityFile: params2.identityFile ?? params1.identityFile,
      identityPassphrase: params2.identityPassphrase ?? params1.identityPassphrase,
      sendSshPublicKey: params2.sendSshPublicKey ?? params1.sendSshPublicKey,
      localSshOptions: params2.localSshOptions ?? params1.localSshOptions,
      remoteUsername: params2.remoteUsername ?? params1.remoteUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      localSshdPort: params2.localSshdPort ?? params1.localSshdPort,
      listDevices: params2.listDevices ?? params1.listDevices,
      legacyDaemon: params2.legacyDaemon ?? params1.legacyDaemon,
      remoteSshdPort: params2.remoteSshdPort ?? params1.remoteSshdPort,
      idleTimeout: params2.idleTimeout ?? params1.idleTimeout,
      addForwardsToTunnel: params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
      sshClient: params2.sshClient ?? params1.sshClient,
      sshAlgorithm: params2.sshAlgorithm ?? params1.sshAlgorithm,
    );
  }

  factory SSHNPPartialParams.fromFile(String fileName) {
    var args = ConfigFileRepository.parseConfigFile(fileName);
    args[SSHNPArg.profileNameArg.name] = ConfigFileRepository.toProfileName(fileName);
    return SSHNPPartialParams.fromArgMap(args);
  }

  factory SSHNPPartialParams.fromConfigLines(String profileName, List<String> lines) {
    var args = ConfigFileRepository.parseConfigFileContents(lines);
    args[SSHNPArg.profileNameArg.name] = profileName;
    return SSHNPPartialParams.fromArgMap(args);
  }

  factory SSHNPPartialParams.fromJson(String json) => SSHNPPartialParams.fromArgMap(jsonDecode(json));

  factory SSHNPPartialParams.fromArgMap(Map<String, dynamic> args) {
    return SSHNPPartialParams(
      profileName: args[SSHNPArg.profileNameArg.name],
      clientAtSign: args[SSHNPArg.fromArg.name],
      sshnpdAtSign: args[SSHNPArg.toArg.name],
      host: args[SSHNPArg.hostArg.name],
      device: args[SSHNPArg.deviceArg.name],
      port: args[SSHNPArg.portArg.name],
      localPort: args[SSHNPArg.localPortArg.name],
      atKeysFilePath: args[SSHNPArg.keyFileArg.name],
      identityFile: args[SSHNPArg.identityFileArg.name],
      identityPassphrase: args[SSHNPArg.identityPassphraseArg.name],
      sendSshPublicKey: args[SSHNPArg.sendSshPublicKeyArg.name],
      localSshOptions: args[SSHNPArg.localSshOptionsArg.name] == null
          ? null
          : List<String>.from(args[SSHNPArg.localSshOptionsArg.name]),
      remoteUsername: args[SSHNPArg.remoteUserNameArg.name],
      verbose: args[SSHNPArg.verboseArg.name],
      rootDomain: args[SSHNPArg.rootDomainArg.name],
      localSshdPort: args[SSHNPArg.localSshdPortArg.name],
      listDevices: args[SSHNPArg.listDevicesArg.name],
      legacyDaemon: args[SSHNPArg.legacyDaemonArg.name],
      remoteSshdPort: args[SSHNPArg.remoteSshdPortArg.name],
      idleTimeout: args[SSHNPArg.idleTimeoutArg.name],
      addForwardsToTunnel: args[SSHNPArg.addForwardsToTunnelArg.name],
      sshClient: args[SSHNPArg.sshClientArg.name] == null
          ? null
          : SupportedSshClient.fromString(args[SSHNPArg.sshClientArg.name]),
      sshAlgorithm: args[SSHNPArg.ssHAlgorithmArg.name] == null
          ? null
          : SupportedSSHAlgorithm.fromString(args[SSHNPArg.ssHAlgorithmArg.name]),
    );
  }

  /// Parses args from command line
  /// first merges from a config file if provided via --config-file
  factory SSHNPPartialParams.fromArgList(List<String> args, {ParserType parserType = ParserType.all}) {
    var params = SSHNPPartialParams.empty();
    var parser = SSHNPArg.createArgParser(
      withDefaults: false,
      parserType: parserType,
    );
    var parsedArgs = parser.parse(args);

    if (parser.options.keys.contains(SSHNPArg.configFileArg.name) &&
        parsedArgs.wasParsed(SSHNPArg.configFileArg.name)) {
      var configFileName = parsedArgs[SSHNPArg.configFileArg.name] as String;
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
      SSHNPPartialParams.fromArgMap(parsedArgsMap),
    );
  }
}
