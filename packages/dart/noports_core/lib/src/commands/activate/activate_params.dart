import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:at_commons/atsign.dart';
import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/utils/constants.dart';

enum ActivateType {
  cram,
  enroll,
  fetch;

  RegExp get regex {
    switch (this) {
      case ActivateType.cram:
        return ActivateRegex.cram;
      case ActivateType.enroll:
        return ActivateRegex.enroll;
      case ActivateType.fetch:
        return ActivateRegex.fetch;
    }
  }

  static ActivateType parse(String input) {
    try {
      return values.firstWhere((type) => input.contains('${type.name}:'));
    } catch (e) {
      throw ArgumentError(
        'Invalid activation type "$input" - should be one of ${ActivateType.values.map((t) => t.name)}',
      );
    }
  }
}

class ActivateParams {
  final Atsign atsign;
  final ActivateType type;
  final String? cramSecret;
  final String? otp;
  final String? deviceName;
  final FetchParams? fetchParams;
  final appName = defaultAppName;
  final namespaces = defaultNamespaces;
  String? atKeysFilePath;
  final String rootDomain;

  // Logging
  bool verbose = false;
  bool debug = false;

  // Static parser for consistent usage and help generation
  static final ArgParser argParser = _createArgParser();

  ActivateParams({
    required this.atsign,
    required this.type,
    this.cramSecret,
    this.otp,
    this.deviceName,
    this.fetchParams,
    this.atKeysFilePath,
    required this.rootDomain,
    this.verbose = false,
    this.debug = false,
  });

  factory ActivateParams.fromArgs(List<String> args) {
    final results = argParser.parse(args);

    if (results.wasParsed('help')) {
      throw HelpRequestedException();
    }

    if (results.rest.isEmpty) {
      throw ArgumentError(
        'Activation string is required (e.g. @alice:cram:secret or'
        ' @alice:enroll:otp:123456)',
      );
    }

    final activationString = results.rest.single;
    final type = ActivateType.parse(activationString);
    stderr.writeln('Got activate command type: $type');

    final atsign = _parseAtsign(activationString, type);
    if (atsign == null || atsign.isEmpty) {
      throw ArgumentError('atsign is required in activation string');
    }

    // parse from arg parser results
    final keyfile = results['target-keyfile'] as String?;

    final parsedFetch = _parseFetch(activationString);
    return ActivateParams(
      atsign: atsign,
      type: type,
      cramSecret: _parseCramSecret(activationString),
      otp: _parseOtp(activationString),
      deviceName: parsedFetch?.device ?? _parseDeviceName(activationString),
      fetchParams: parsedFetch,
      atKeysFilePath: keyfile,
      rootDomain: results['root-server'],
      verbose: results['verbose'],
      debug: results['debug'],
    );
  }

  static ArgParser _createArgParser() {
    final p = ArgParser();
    p.addOption(
      'target-keyfile',
      abbr: 't',
      mandatory: false,
      help: 'Destination path for atKeys file',
    );

    p.addOption(
      'root-server',
      abbr: 'r',
      aliases: const ['root-domain', 'rootDomain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory (aka root) server domain (e.g., root.atsign.org)',
    );

    p.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this usage info',
    );

    p.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'More logging (INFO and above)',
    );

    p.addFlag(
      'debug',
      abbr: 'd',
      negatable: false,
      help: 'More logging (DEBUG and above)',
    );

    return p;
  }

  static Atsign? _parseAtsign(String input, ActivateType type) {
    final match = type.regex.firstMatch(input);
    final atsign = match?.namedGroup(ActivateRegexGroups.atsign);

    return atsign != null && atsign.isNotEmpty ? atsign.toAtsign() : null;
  }

  static String? _parseCramSecret(String input) {
    final match = ActivateRegex.cram.firstMatch(input);
    return match?.namedGroup(ActivateRegexGroups.cram);
  }

  static String? _parseOtp(String input) {
    final match = ActivateRegex.enroll.firstMatch(input);
    return match?.namedGroup(ActivateRegexGroups.otp);
  }

  static String? _parseDeviceName(String input) {
    final match = ActivateRegex.enroll.firstMatch(input);
    return match?.namedGroup(ActivateRegexGroups.deviceName);
  }

  /// input is base64-encoded string-encoded json
  static FetchParams? _parseFetch(String input) {
    // decode base64 to json string
    // decode json string to map
    // make FetchParams from the map
    final match = ActivateRegex.fetch.firstMatch(input);
    if (match == null) {
      return null;
    }
    final String? b64 = match.namedGroup(ActivateRegexGroups.params);
    if (b64 == null) {
      throw ArgumentError('fetch: Invalid parameters');
    }
    final String jsonString;
    try {
      jsonString = String.fromCharCodes(base64Decode(b64));
    } catch (_) {
      throw ArgumentError('fetch: base64 decode params failed');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonString);
    } catch (_) {
      throw ArgumentError('fetch: json decode params failed');
    }
    try {
      return FetchParams.fromJson(json);
    } catch (_) {
      throw ArgumentError('fetch: invalid json');
    }
  }
}

class ActivateRegex {
  // CRAM authentication: <atsign>:cram:<secret>
  static final cram = RegExp(r'^(?<atsign>[^:]+):cram:(?<secret>.+)$');

  // Enrollment: <atsign>:enroll:otp:<otp>[:name:<device>]
  static final enroll = RegExp(
    r'^(?<atsign>[^:]+):enroll:otp:(?<otp>[A-Za-z0-9]{6})'
    r'(?::name:(?<device>[^]+))?$', // ?: indicates a non-capturing group
  );

  static final fetch = RegExp(r'^(?<atsign>[^:]+):fetch:(?<params>.+)$');
}

class FetchParams {
  final String device;
  final String location;
  final String aes64;
  final String iv64;

  FetchParams({
    required this.device,
    required this.location,
    required this.aes64,
    required this.iv64,
  });

  Map<String, dynamic> toJson() => {
    'device': device,
    'location': location,
    'aes64': aes64,
    'iv64': iv64,
  };

  factory FetchParams.fromJson(Map<String, dynamic> m) => FetchParams(
    device: m['device'],
    location: m['location'],
    aes64: m['aes64'],
    iv64: m['iv64'],
  );
}

/// Named capture groups used in [ActivateRegex]
class ActivateRegexGroups {
  static const atsign = 'atsign';
  static const cram = 'secret';
  static const otp = 'otp';
  static const deviceName = 'device';
  static const params = 'params';
}
