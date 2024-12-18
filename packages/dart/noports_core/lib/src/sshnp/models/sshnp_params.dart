import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/src/sshnp/models/config_file_repository.dart';
import 'package:noports_core/src/sshnp/models/sshnp_arg.dart';
import 'package:noports_core/utils.dart';

abstract interface class ClientParams {
  bool get verbose;

  String get device;

  String get rootDomain;

  String get clientAtSign;

  // This value can be "" if list-devices was passed, otherwise it should be a valid atSign
  String get sshnpdAtSign;

  String get srvdAtSign;

  bool get authenticateClientToRvd;

  bool get authenticateDeviceToRvd;

  bool get encryptRvdTraffic;

  String? get atKeysFilePath;

  /// An encryption keypair which should only ever reside in memory.
  /// The public key is provided in requests to the daemon, and is
  /// used by daemons to encrypt symmetric encryption keys intended for
  /// one-time use in a NoPorts session, and share the encrypted details
  /// as part of the daemon's response
  AtEncryptionKeyPair get sessionKP;

  EncryptionKeyType get sessionKPType;

  /// The port we wish to use on this device. If 0, then we ask the operating
  /// system for a port
  int get localPort;

  Duration get daemonPingTimeout;
}

abstract class ClientParamsBase implements ClientParams {
  @override
  final bool verbose;

  @override
  final String device;

  @override
  final String rootDomain;

  @override
  final String clientAtSign;

  @override
  final String sshnpdAtSign;

  @override
  final String srvdAtSign;

  @override
  final bool authenticateClientToRvd;

  @override
  final bool authenticateDeviceToRvd;

  @override
  final bool encryptRvdTraffic;

  @override
  final String? atKeysFilePath;

  @override
  int localPort;

  @override
  AtEncryptionKeyPair get sessionKP {
    _sessionKP ??= AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);
    return _sessionKP!;
  }

  /// Generate the ephemeralKeyPair only on demand
  AtEncryptionKeyPair? _sessionKP;
  @override
  final EncryptionKeyType sessionKPType = EncryptionKeyType.rsa2048;

  @override
  final Duration daemonPingTimeout;

  ClientParamsBase({
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.srvdAtSign,
    this.localPort = DefaultSshnpArgs.localPort,
    this.device = DefaultSshnpArgs.device,
    this.verbose = DefaultArgs.verbose,
    this.atKeysFilePath,
    this.rootDomain = DefaultArgs.rootDomain,
    this.authenticateClientToRvd = DefaultArgs.authenticateClientToRvd,
    this.authenticateDeviceToRvd = DefaultArgs.authenticateDeviceToRvd,
    this.encryptRvdTraffic = DefaultArgs.encryptRvdTraffic,
    this.daemonPingTimeout = DefaultArgs.daemonPingTimeoutDuration,
  }) {
    if (invalidDeviceName(device)) {
      throw ArgumentError(invalidDeviceNameMsg);
    }
  }
}

abstract interface class SrvdChannelParams implements ClientParams {}

abstract interface class SshnpdChannelParams implements ClientParams {
  String? get remoteUsername;

  String? get tunnelUsername;

  bool get sendSshPublicKey;
}

class NptParams extends ClientParamsBase
    implements SrvdChannelParams, SshnpdChannelParams {
  /// The host name / ip address that we wish to connect to (on the device's network)
  final String remoteHost;

  /// The port that we wish to connect to (on the device's network)
  final int remotePort;

  /// Whether to run the srv within this process, or fork a separate process
  final bool inline;

  /// How long to keep the local port open if there have been no connections
  final Duration timeout;

  NptParams({
    required super.clientAtSign,
    required super.sshnpdAtSign,
    required super.srvdAtSign,
    required this.remoteHost,
    required this.remotePort,
    required super.device,
    super.localPort = DefaultSshnpArgs.localPort,
    super.verbose = DefaultArgs.verbose,
    super.atKeysFilePath,
    super.rootDomain = DefaultArgs.rootDomain,
    super.authenticateClientToRvd = DefaultArgs.authenticateClientToRvd,
    super.authenticateDeviceToRvd = DefaultArgs.authenticateDeviceToRvd,
    super.encryptRvdTraffic = DefaultArgs.encryptRvdTraffic,
    required this.inline,
    super.daemonPingTimeout,
    required this.timeout,
  }) {
    try {
      AtUtils.fixAtSign(clientAtSign);
      AtUtils.fixAtSign(sshnpdAtSign);
      AtUtils.fixAtSign(srvdAtSign);
    } on InvalidAtSignException catch (e) {
      throw ArgumentError(e.message);
    }
  }

  /// not relevant for Npt
  @override
  final bool sendSshPublicKey = false;

  /// not relevant for Npt
  @override
  final String? remoteUsername = null; // not relevant for Npt
  /// not relevant for Npt
  @override
  final String? tunnelUsername = null; // not relevant for Npt
}

class SshnpParams extends ClientParamsBase
    implements SrvdChannelParams, SshnpdChannelParams {
  /// Required Arguments
  /// These arguments do not have fallback values and must be provided.
  /// Since there are multiple sources for these values, we cannot validate
  /// that they will be provided. If any are null, then the caller must
  /// handle the error.

  /// Optional Arguments
  final String? identityFile;
  final String? identityPassphrase;
  @override
  final bool sendSshPublicKey;
  final List<String> localSshOptions;
  @override
  final String? remoteUsername;
  @override
  final String? tunnelUsername;
  final int remoteSshdPort;
  final int idleTimeout;
  final bool addForwardsToTunnel;

  /// Special Arguments

  /// automatically populated with the filename if from a configFile
  final String? profileName;

  /// Operation flags
  final bool listDevices;

  SshnpParams({
    required super.clientAtSign,
    required super.sshnpdAtSign,
    required super.srvdAtSign,
    this.profileName,
    super.device = DefaultSshnpArgs.device,
    super.localPort = DefaultSshnpArgs.localPort,
    this.identityFile,
    this.identityPassphrase,
    this.sendSshPublicKey = DefaultSshnpArgs.sendSshPublicKey,
    this.localSshOptions = DefaultSshnpArgs.localSshOptions,
    super.verbose = DefaultArgs.verbose,
    this.remoteUsername,
    this.tunnelUsername,
    super.atKeysFilePath,
    super.rootDomain = DefaultArgs.rootDomain,
    this.listDevices = DefaultSshnpArgs.listDevices,
    this.remoteSshdPort = DefaultArgs.remoteSshdPort,
    this.idleTimeout = DefaultArgs.idleTimeout,
    this.addForwardsToTunnel = DefaultArgs.addForwardsToTunnel,
    super.authenticateClientToRvd = DefaultArgs.authenticateClientToRvd,
    super.authenticateDeviceToRvd = DefaultArgs.authenticateDeviceToRvd,
    super.encryptRvdTraffic = DefaultArgs.encryptRvdTraffic,
    super.daemonPingTimeout,
  });

  factory SshnpParams.empty() {
    return SshnpParams(
      profileName: '',
      clientAtSign: '',
      sshnpdAtSign: '',
      srvdAtSign: '',
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
      authenticateClientToRvd:
          params2.authenticateClientToRvd ?? params1.authenticateClientToRvd,
      authenticateDeviceToRvd:
          params2.authenticateDeviceToRvd ?? params1.authenticateDeviceToRvd,
      encryptRvdTraffic: params2.encryptRvdTraffic ?? params1.encryptRvdTraffic,
      daemonPingTimeout: params2.daemonPingTimeout ?? params1.daemonPingTimeout,
    );
  }

  factory SshnpParams.fromFile(String fileName) {
    return SshnpParams.fromPartial(SshnpPartialParams.fromFile(fileName));
  }

  factory SshnpParams.fromJson(String json) =>
      SshnpParams.fromPartial(SshnpPartialParams.fromJson(json));

  factory SshnpParams.fromPartial(SshnpPartialParams partial) {
    // Always need the clientAtSign
    partial.clientAtSign ??
        (throw ArgumentError('from (clientAtSign) is mandatory'));

    if (!(partial.listDevices ?? DefaultSshnpArgs.listDevices)) {
      // if list-devices is not set, then ensure sshnpdAtSign and srvdAtSign are set
      partial.sshnpdAtSign ??
          (throw ArgumentError(
              'Option to is mandatory, unless list-devices is passed.'));
      partial.srvdAtSign ??
          (throw ArgumentError(
              'srvdAtSign is mandatory, unless list-devices is passed.'));
    }

    String device = partial.device ?? DefaultSshnpArgs.device;
    device = snakifyDeviceName(device);
    return SshnpParams(
      profileName: partial.profileName,
      clientAtSign: partial.clientAtSign!,
      sshnpdAtSign: partial.sshnpdAtSign ?? "",
      srvdAtSign: partial.srvdAtSign ?? "",
      device: device,
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
      listDevices: partial.listDevices ?? DefaultSshnpArgs.listDevices,
      remoteSshdPort: partial.remoteSshdPort ?? DefaultArgs.remoteSshdPort,
      idleTimeout: partial.idleTimeout ?? DefaultArgs.idleTimeout,
      addForwardsToTunnel:
          partial.addForwardsToTunnel ?? DefaultArgs.addForwardsToTunnel,
      authenticateClientToRvd: partial.authenticateClientToRvd ??
          DefaultArgs.authenticateClientToRvd,
      authenticateDeviceToRvd: partial.authenticateDeviceToRvd ??
          DefaultArgs.authenticateDeviceToRvd,
      encryptRvdTraffic:
          partial.encryptRvdTraffic ?? DefaultArgs.encryptRvdTraffic,
      daemonPingTimeout:
          partial.daemonPingTimeout ?? DefaultArgs.daemonPingTimeoutDuration,
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
      SshnpArg.srvdArg.name: srvdAtSign,
      SshnpArg.deviceArg.name: device,
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
      SshnpArg.remoteSshdPortArg.name: remoteSshdPort,
      SshnpArg.idleTimeoutArg.name: idleTimeout,
      SshnpArg.addForwardsToTunnelArg.name: addForwardsToTunnel,
      SshnpArg.authenticateClientToRvdArg.name: authenticateClientToRvd,
      SshnpArg.authenticateDeviceToRvdArg.name: authenticateDeviceToRvd,
      SshnpArg.encryptRvdTrafficArg.name: encryptRvdTraffic,
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
