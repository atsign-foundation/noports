import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnp/models/config_file_repository.dart';
import 'package:noports_core/src/sshnp/models/sshnp_arg.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/sshnp.dart';

class SshnpParams {
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
  final String? tunnelUsername;
  final bool verbose;
  final String rootDomain;
  final int localSshdPort;
  final int remoteSshdPort;
  final int idleTimeout;
  final bool addForwardsToTunnel;
  final String? atKeysFilePath;
  final SupportedSshAlgorithm sshAlgorithm;
  // TODO Once pure dart impl supports these flags then they can be
  // TODO made "final" again
  bool authenticateClientToRvd;
  bool authenticateDeviceToRvd;
  bool encryptRvdTraffic;
  bool discoverDaemonFeatures;

  /// Special Arguments

  /// automatically populated with the filename if from a configFile
  final String? profileName;

  /// Operation flags
  final bool listDevices;

  /// An encryption keypair which should only ever reside in memory.
  /// The public key is provided in responses to client 'pings', and is
  /// used by clients to encrypt symmetric encryption keys intended for
  /// one-time use in a NoPorts session, and share the encrypted details
  /// as part of the session request payload.
  AtEncryptionKeyPair get sessionKP {
    _sessionKP ??= AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
    return _sessionKP!;
  }

  /// Generate the ephemeralKeyPair only on demand
  AtEncryptionKeyPair? _sessionKP;
  final EncryptionKeyType sessionKPType = EncryptionKeyType.rsa2048;

  SshnpParams({
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.host,
    this.profileName,
    this.device = DefaultSshnpArgs.device,
    this.port = DefaultSshnpArgs.port,
    this.localPort = DefaultSshnpArgs.localPort,
    this.identityFile,
    this.identityPassphrase,
    this.sendSshPublicKey = DefaultSshnpArgs.sendSshPublicKey,
    this.localSshOptions = DefaultSshnpArgs.localSshOptions,
    this.verbose = DefaultArgs.verbose,
    this.remoteUsername,
    this.tunnelUsername,
    this.atKeysFilePath,
    this.rootDomain = DefaultArgs.rootDomain,
    this.localSshdPort = DefaultArgs.localSshdPort,
    this.listDevices = DefaultSshnpArgs.listDevices,
    this.remoteSshdPort = DefaultArgs.remoteSshdPort,
    this.idleTimeout = DefaultArgs.idleTimeout,
    this.addForwardsToTunnel = DefaultArgs.addForwardsToTunnel,
    this.sshAlgorithm = DefaultArgs.sshAlgorithm,
    this.authenticateClientToRvd = DefaultArgs.authenticateClientToRvd,
    this.authenticateDeviceToRvd = DefaultArgs.authenticateDeviceToRvd,
    this.encryptRvdTraffic = DefaultArgs.encryptRvdTraffic,
    this.discoverDaemonFeatures = DefaultArgs.discoverDaemonFeatures,
  });

  factory SshnpParams.empty() {
    return SshnpParams(
      profileName: '',
      clientAtSign: '',
      sshnpdAtSign: '',
      host: '',
    );
  }

  /// Merge an SshnpPartialParams objects into an SshnpParams
  /// Params in params2 take precedence over params1
  factory SshnpParams.merge(SshnpParams params1,
      [SshnpPartialParams? params2]) {
    params2 ??= SshnpPartialParams.empty();
    return SshnpParams(
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
      tunnelUsername: params2.tunnelUsername ?? params1.tunnelUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      localSshdPort: params2.localSshdPort ?? params1.localSshdPort,
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
      discoverDaemonFeatures:
          params2.discoverDaemonFeatures ?? params1.discoverDaemonFeatures,
    );
  }

  factory SshnpParams.fromFile(String fileName) {
    return SshnpParams.fromPartial(SshnpPartialParams.fromFile(fileName));
  }

  factory SshnpParams.fromJson(String json) =>
      SshnpParams.fromPartial(SshnpPartialParams.fromJson(json));

  factory SshnpParams.fromPartial(SshnpPartialParams partial) {
    partial.clientAtSign ?? (throw ArgumentError('from is mandatory'));
    partial.sshnpdAtSign ?? (throw ArgumentError('to is mandatory'));
    partial.host ?? (throw ArgumentError('host is mandatory'));
    return SshnpParams(
      profileName: partial.profileName,
      clientAtSign: partial.clientAtSign!,
      sshnpdAtSign: partial.sshnpdAtSign!,
      host: partial.host!,
      device: partial.device ?? DefaultSshnpArgs.device,
      port: partial.port ?? DefaultSshnpArgs.port,
      localPort: partial.localPort ?? DefaultSshnpArgs.localPort,
      identityFile: partial.identityFile,
      identityPassphrase: partial.identityPassphrase,
      sendSshPublicKey:
          partial.sendSshPublicKey ?? DefaultSshnpArgs.sendSshPublicKey,
      localSshOptions:
          partial.localSshOptions ?? DefaultSshnpArgs.localSshOptions,
      verbose: partial.verbose ?? DefaultArgs.verbose,
      remoteUsername: partial.remoteUsername,
      tunnelUsername: partial.tunnelUsername,
      atKeysFilePath: partial.atKeysFilePath,
      rootDomain: partial.rootDomain ?? DefaultArgs.rootDomain,
      localSshdPort: partial.localSshdPort ?? DefaultArgs.localSshdPort,
      listDevices: partial.listDevices ?? DefaultSshnpArgs.listDevices,
      remoteSshdPort: partial.remoteSshdPort ?? DefaultArgs.remoteSshdPort,
      idleTimeout: partial.idleTimeout ?? DefaultArgs.idleTimeout,
      addForwardsToTunnel:
          partial.addForwardsToTunnel ?? DefaultArgs.addForwardsToTunnel,
      sshAlgorithm: partial.sshAlgorithm ?? DefaultArgs.sshAlgorithm,
      authenticateClientToRvd: partial.authenticateClientToRvd ??
          DefaultArgs.authenticateClientToRvd,
      authenticateDeviceToRvd: partial.authenticateDeviceToRvd ??
          DefaultArgs.authenticateDeviceToRvd,
      encryptRvdTraffic:
          partial.encryptRvdTraffic ?? DefaultArgs.encryptRvdTraffic,
      discoverDaemonFeatures:
          partial.discoverDaemonFeatures ?? DefaultArgs.discoverDaemonFeatures,
    );
  }

  factory SshnpParams.fromConfigLines(String profileName, List<String> lines) {
    return SshnpParams.fromPartial(
        SshnpPartialParams.fromConfigLines(profileName, lines));
  }

  List<String> toConfigLines({ParserType parserType = ParserType.configFile}) {
    var lines = <String>[];
    for (var entry in toArgMap().entries) {
      var arg = SshnpArg.fromName(entry.key);
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
      SshnpArg.profileNameArg.name: profileName,
      SshnpArg.fromArg.name: clientAtSign,
      SshnpArg.toArg.name: sshnpdAtSign,
      SshnpArg.hostArg.name: host,
      SshnpArg.deviceArg.name: device,
      SshnpArg.portArg.name: port,
      SshnpArg.localPortArg.name: localPort,
      SshnpArg.keyFileArg.name: atKeysFilePath,
      SshnpArg.identityFileArg.name: identityFile,
      SshnpArg.identityPassphraseArg.name: identityPassphrase,
      SshnpArg.sendSshPublicKeyArg.name: sendSshPublicKey,
      SshnpArg.localSshOptionsArg.name: localSshOptions,
      SshnpArg.remoteUserNameArg.name: remoteUsername,
      SshnpArg.tunnelUserNameArg.name: tunnelUsername,
      SshnpArg.verboseArg.name: verbose,
      SshnpArg.rootDomainArg.name: rootDomain,
      SshnpArg.localSshdPortArg.name: localSshdPort,
      SshnpArg.remoteSshdPortArg.name: remoteSshdPort,
      SshnpArg.idleTimeoutArg.name: idleTimeout,
      SshnpArg.addForwardsToTunnelArg.name: addForwardsToTunnel,
      SshnpArg.sshAlgorithmArg.name: sshAlgorithm.toString(),
      SshnpArg.authenticateClientToRvdArg.name: authenticateClientToRvd,
      SshnpArg.authenticateDeviceToRvdArg.name: authenticateDeviceToRvd,
      SshnpArg.encryptRvdTrafficArg.name: encryptRvdTraffic,
      SshnpArg.discoverDaemonFeaturesArg.name: discoverDaemonFeatures,
    };
    args.removeWhere(
      (key, value) => !parserType.shouldParse(SshnpArg.fromName(key).parseWhen),
    );
    return args;
  }

  String toJson({ParserType parserType = ParserType.all}) {
    return jsonEncode(toArgMap(parserType: parserType));
  }
}

/// A class which contains a subset of the SshnpParams
/// This may be used when part of the params come from separate sources
/// e.g. default values from a config file and the rest from the command line
class SshnpPartialParams {
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
  final bool? discoverDaemonFeatures;

  /// Operation flags
  final bool? listDevices;

  SshnpPartialParams({
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
    this.tunnelUsername,
    this.verbose,
    this.rootDomain,
    this.localSshdPort,
    this.listDevices,
    this.remoteSshdPort,
    this.idleTimeout,
    this.addForwardsToTunnel,
    this.sshAlgorithm,
    this.authenticateClientToRvd,
    this.authenticateDeviceToRvd,
    this.encryptRvdTraffic,
    this.discoverDaemonFeatures,
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
      tunnelUsername: params2.tunnelUsername ?? params1.tunnelUsername,
      verbose: params2.verbose ?? params1.verbose,
      rootDomain: params2.rootDomain ?? params1.rootDomain,
      localSshdPort: params2.localSshdPort ?? params1.localSshdPort,
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
      discoverDaemonFeatures:
          params2.discoverDaemonFeatures ?? params1.discoverDaemonFeatures,
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
      host: args[SshnpArg.hostArg.name],
      device: args[SshnpArg.deviceArg.name],
      port: args[SshnpArg.portArg.name],
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
      localSshdPort: args[SshnpArg.localSshdPortArg.name],
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
      discoverDaemonFeatures: args[SshnpArg.discoverDaemonFeaturesArg.name],
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
    Map<String, dynamic> parsedArgsMap = {
      for (var e in parsedArgs.options)
        e: SshnpArg.fromName(e).type == ArgType.integer
            ? int.tryParse(parsedArgs[e])
            : parsedArgs[e]
    };

    return SshnpPartialParams.merge(
      params,
      SshnpPartialParams.fromArgMap(parsedArgsMap),
    );
  }
}
