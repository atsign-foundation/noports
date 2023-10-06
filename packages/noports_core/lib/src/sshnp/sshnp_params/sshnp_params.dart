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
  final String?
      profileName; // automatically populated with the filename if from a configFile

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
  factory SSHNPParams.merge(SSHNPParams params1,
      [SSHNPPartialParams? params2]) {
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
      identityPassphrase:
          params2.identityPassphrase ?? params1.identityPassphrase,
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
      addForwardsToTunnel:
          params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
      sshClient: params2.sshClient ?? params1.sshClient,
      sshAlgorithm: params2.sshAlgorithm ?? params1.sshAlgorithm,
    );
  }

  factory SSHNPParams.fromFile(String fileName) {
    return SSHNPParams.fromPartial(SSHNPPartialParams.fromFile(fileName));
  }

  factory SSHNPParams.fromJson(String json) =>
      SSHNPParams.fromPartial(SSHNPPartialParams.fromJson(json));

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
      sendSshPublicKey:
          partial.sendSshPublicKey ?? DefaultSSHNPArgs.sendSshPublicKey,
      localSshOptions:
          partial.localSshOptions ?? DefaultSSHNPArgs.localSshOptions,
      verbose: partial.verbose ?? DefaultArgs.verbose,
      remoteUsername: partial.remoteUsername,
      atKeysFilePath: partial.atKeysFilePath,
      rootDomain: partial.rootDomain ?? DefaultArgs.rootDomain,
      localSshdPort: partial.localSshdPort ?? DefaultArgs.localSshdPort,
      listDevices: partial.listDevices ?? DefaultSSHNPArgs.listDevices,
      legacyDaemon: partial.legacyDaemon ?? DefaultSSHNPArgs.legacyDaemon,
      remoteSshdPort: partial.remoteSshdPort ?? DefaultArgs.remoteSshdPort,
      idleTimeout: partial.idleTimeout ?? DefaultArgs.idleTimeout,
      addForwardsToTunnel:
          partial.addForwardsToTunnel ?? DefaultArgs.addForwardsToTunnel,
      sshClient: partial.sshClient ?? DefaultSSHNPArgs.sshClient,
      sshAlgorithm: partial.sshAlgorithm ?? DefaultArgs.sshAlgorithm,
    );
  }

  factory SSHNPParams.fromConfigLines(String profileName, List<String> lines) {
    return SSHNPParams.fromPartial(
        SSHNPPartialParams.fromConfigLines(profileName, lines));
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
      'profile-name': profileName,
      'from': clientAtSign,
      'to': sshnpdAtSign,
      'host': host,
      'device': device,
      'port': port,
      'local-port': localPort,
      'key-file': atKeysFilePath,
      'identity-file': identityFile,
      'identity-passphrase': identityPassphrase,
      'send-ssh-public-key': sendSshPublicKey,
      'local-ssh-options': localSshOptions,
      'remote-user-name': remoteUsername,
      'verbose': verbose,
      'root-domain': rootDomain,
      'local-sshd-port': localSshdPort,
      'remote-sshd-port': remoteSshdPort,
      'idle-timeout': idleTimeout,
      'add-forwards-to-tunnel': addForwardsToTunnel,
      'ssh-client': sshClient.toString(),
      'ssh-algorithm': sshAlgorithm.toString(),
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
  factory SSHNPPartialParams.merge(SSHNPPartialParams params1,
      [SSHNPPartialParams? params2]) {
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
      identityPassphrase:
          params2.identityPassphrase ?? params1.identityPassphrase,
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
      addForwardsToTunnel:
          params2.addForwardsToTunnel ?? params1.addForwardsToTunnel,
      sshClient: params2.sshClient ?? params1.sshClient,
      sshAlgorithm: params2.sshAlgorithm ?? params1.sshAlgorithm,
    );
  }

  factory SSHNPPartialParams.fromFile(String fileName) {
    var args = ConfigFileRepository.parseConfigFile(fileName);
    args['profile-name'] = ConfigFileRepository.toProfileName(fileName);
    return SSHNPPartialParams.fromArgMap(args);
  }

  factory SSHNPPartialParams.fromConfigLines(
      String profileName, List<String> lines) {
    var args = ConfigFileRepository.parseConfigFileContents(lines);
    args['profile-name'] = profileName;
    return SSHNPPartialParams.fromArgMap(args);
  }

  factory SSHNPPartialParams.fromJson(String json) =>
      SSHNPPartialParams.fromArgMap(jsonDecode(json));

  factory SSHNPPartialParams.fromArgMap(Map<String, dynamic> args) {
    return SSHNPPartialParams(
      profileName: args['profile-name'],
      clientAtSign: args['from'],
      sshnpdAtSign: args['to'],
      host: args['host'],
      device: args['device'],
      port: args['port'],
      localPort: args['local-port'],
      atKeysFilePath: args['key-file'],
      identityFile: args['identity-file'],
      identityPassphrase: args['identity-passphrase'],
      sendSshPublicKey: args['send-ssh-public-key'],
      localSshOptions: args['local-ssh-options'] == null
          ? null
          : List<String>.from(args['local-ssh-options']),
      remoteUsername: args['remote-user-name'],
      verbose: args['verbose'],
      rootDomain: args['root-domain'],
      localSshdPort: args['local-sshd-port'],
      listDevices: args['list-devices'],
      legacyDaemon: args['legacy-daemon'],
      remoteSshdPort: args['remote-sshd-port'],
      idleTimeout: args['idle-timeout'],
      addForwardsToTunnel: args['add-forwards-to-tunnel'],
      sshClient: args['ssh-client'] == null
          ? null
          : SupportedSshClient.fromString(args['ssh-client']),
      sshAlgorithm: args['ssh-algorithm'] == null
          ? null
          : SupportedSSHAlgorithm.fromString(args['ssh-algorithm']),
    );
  }

  /// Parses args from command line
  /// first merges from a config file if provided via --config-file
  factory SSHNPPartialParams.fromArgList(List<String> args,
      {ParserType parserType = ParserType.all}) {
    var params = SSHNPPartialParams.empty();
    var parser = SSHNPArg.createArgParser(
      withDefaults: false,
      parserType: parserType,
    );
    var parsedArgs = parser.parse(args);

    if (parser.options.keys.contains('config-file') &&
        parsedArgs.wasParsed('config-file')) {
      var configFileName = parsedArgs['config-file'] as String;
      params = SSHNPPartialParams.merge(
        params,
        SSHNPPartialParams.fromFile(configFileName),
      );
    }

    // THIS IS A WORKAROUND IN ORDER TO BE TYPE SAFE IN SSHNPPartialParams.fromArgMap
    Map<String, dynamic> parsedArgsMap = {
      for (var e in parsedArgs.options)
        e: SSHNPArg.fromName(e).type == ArgType.integer
            ? int.tryParse(parsedArgs[e])
            : parsedArgs[e]
    };

    return SSHNPPartialParams.merge(
      params,
      SSHNPPartialParams.fromArgMap(parsedArgsMap),
    );
  }
}
