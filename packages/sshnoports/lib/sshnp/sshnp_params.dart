import 'dart:io';

import 'package:args/args.dart';
import 'package:at_utils/at_utils.dart';
import 'package:sshnoports/common/utils.dart';
import 'package:sshnoports/sshnp/sshnp_arg.dart';

class SSHNPParams {
  /// Required Arguments
  /// These arguments do not have fallback values and must be provided.
  /// Since there are multiple sources for these values, we cannot validate
  /// that they will be provided. If any are null, then the caller must
  /// handle the error.
  late final String? clientAtSign;
  late final String? sshnpdAtSign;
  late final String? host;

  /// Optional Arguments
  late final String device;
  late final String port;
  late final String localPort;
  late final String username;
  late final String homeDirectory;
  late final String atKeysFilePath;
  late final String sendSshPublicKey;
  late final List<String> localSshOptions;
  late final bool rsa;
  late final String? remoteUsername;
  late final bool verbose;

  /// Special Arguments
  late final bool listDevices;

  SSHNPParams({
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.host,
    this.device = 'default',
    this.port = '22',
    this.localPort = '0',
    this.sendSshPublicKey = 'false',
    this.localSshOptions = const [],
    this.verbose = false,
    this.rsa = false,
    this.remoteUsername,
    String? atKeysFilePath,
    this.listDevices = false,
  }) {
    // Do we have a username ?
    username = getUserName(throwIfNull: true)!;

    // Do we have a 'home' directory?
    homeDirectory = getHomeDirectory(throwIfNull: true)!;

    // Use default atKeysFilePath if not provided

    this.atKeysFilePath =
        atKeysFilePath ?? getDefaultAtKeysFilePath(homeDirectory, clientAtSign);
  }

  factory SSHNPParams.fromPartial(SSHNPPartialParams partial) {
    AtSignLogger logger = AtSignLogger(' SSHNPParams ');

    /// If any required params are null log severe, but do not throw
    /// The caller must handle the error if any required params are null
    partial.clientAtSign ?? (logger.severe('clientAtSign is null'));
    partial.sshnpdAtSign ?? (logger.severe('sshnpdAtSign is null'));
    partial.host ?? (logger.severe('host is null'));

    return SSHNPParams(
      clientAtSign: partial.clientAtSign,
      sshnpdAtSign: partial.sshnpdAtSign,
      host: partial.host,
      device: partial.device ?? 'default',
      port: partial.port ?? '22',
      localPort: partial.localPort ?? '0',
      sendSshPublicKey: partial.sendSshPublicKey ?? 'false',
      localSshOptions: partial.localSshOptions,
      rsa: partial.rsa ?? false,
      verbose: partial.verbose ?? false,
      remoteUsername: partial.remoteUsername,
      atKeysFilePath: partial.atKeysFilePath,
      listDevices: partial.listDevices,
    );
  }
}

/// A class which contains a subset of the SSHNPParams
/// This may be used when part of the params come from separate sources
/// e.g. default values from a config file and the rest from the command line
class SSHNPPartialParams {
  /// Main Params
  late final String? clientAtSign;
  late final String? sshnpdAtSign;
  late final String? host;
  late final String? device;
  late final String? port;
  late final String? localPort;
  late final String? atKeysFilePath;
  late final String? sendSshPublicKey;
  late final List<String> localSshOptions;
  late final bool? rsa;
  late final String? remoteUsername;
  late final bool? verbose;

  /// Special Params
  // N.B. config file is a meta param and doesn't need to be included
  late final bool listDevices;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SSHNPPartialParams({
    this.clientAtSign,
    this.sshnpdAtSign,
    this.host,
    this.device,
    this.port,
    this.localPort,
    this.atKeysFilePath,
    this.sendSshPublicKey,
    this.localSshOptions = const [],
    this.rsa,
    this.remoteUsername,
    this.verbose,
    this.listDevices = false,
  });

  factory SSHNPPartialParams.empty() {
    return SSHNPPartialParams();
  }

  /// Merge two SSHNPPartialParams objects together
  /// Params in params2 take precedence over params1
  /// - localSshOptions are concatenated together as (params1 + params2)
  factory SSHNPPartialParams.merge(SSHNPPartialParams params1,
      [SSHNPPartialParams? params2]) {
    params2 ??= SSHNPPartialParams.empty();
    return SSHNPPartialParams(
      clientAtSign: params2.clientAtSign ?? params1.clientAtSign,
      sshnpdAtSign: params2.sshnpdAtSign ?? params1.sshnpdAtSign,
      host: params2.host ?? params1.host,
      device: params2.device ?? params1.device,
      port: params2.port ?? params1.port,
      localPort: params2.localPort ?? params1.localPort,
      atKeysFilePath: params2.atKeysFilePath ?? params1.atKeysFilePath,
      sendSshPublicKey: params2.sendSshPublicKey ?? params1.sendSshPublicKey,
      localSshOptions: params1.localSshOptions + params2.localSshOptions,
      rsa: params2.rsa ?? params1.rsa,
      remoteUsername: params2.remoteUsername ?? params1.remoteUsername,
      verbose: params2.verbose ?? params1.verbose,
      listDevices: params2.listDevices || params1.listDevices,
    );
  }

  factory SSHNPPartialParams.fromArgMap(Map<String, dynamic> args) {
    return SSHNPPartialParams(
      clientAtSign: args['from'],
      sshnpdAtSign: args['to'],
      host: args['host'],
      device: args['device'],
      port: args['port'],
      localPort: args['local-port'],
      atKeysFilePath: args['key-file'],
      sendSshPublicKey: args['ssh-public-key'],
      localSshOptions: args['local-ssh-options'] ?? [],
      rsa: args['rsa'],
      remoteUsername: args['remote-user-name'],
      verbose: args['verbose'],
      listDevices: args['list-devices'] ?? false,
    );
  }

  factory SSHNPPartialParams.fromConfig(String fileName) {
    var args = _parseConfigFile(fileName);
    return SSHNPPartialParams.fromArgMap(args);
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
      for (var e in (parsedArgs.options)) e: parsedArgs[e]
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
            defaultsTo: withDefaults ? arg.defaultsTo as String? : null,
            help: arg.help,
          );
          break;
        case ArgFormat.multiOption:
          parser.addMultiOption(
            arg.name,
            abbr: arg.abbr,
            defaultsTo: withDefaults ? arg.defaultsTo as List<String>? : null,
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
        help:
            'Read args from a config file\nMandatory args are not required if already supplied in the config file',
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
            var values = value.split(';');
            args.putIfAbsent(arg.name, () => <String>[]);
            for (String val in values) {
              if (val.isEmpty) continue;
              args[arg.name].add(val);
            }
            continue;
          case ArgFormat.option:
            if (value.isEmpty) continue;
            args[arg.name] = value;
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
