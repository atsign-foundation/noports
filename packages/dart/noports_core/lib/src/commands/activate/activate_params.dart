import 'package:args/args.dart';
import 'package:at_commons/atsign.dart';
import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/utils/constants.dart';

enum ActivateType {
  cram,
  enroll;

  static ActivateType parse(String input) {
    try {
      return values.firstWhere((type) => input.contains(type.name));
    } catch (e) {
      throw ArgumentError(
        'Invalid activation type in: $input (expected "cram" or "enroll")',
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
  final appName = defaultAppName;
  final namespaces = defaultEnrollmentNamespaces;

  String? atKeysFilePath;

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
    this.atKeysFilePath,
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

    final atsign = _parseAtsign(activationString, type);
    if (atsign == null || atsign.isEmpty) {
      throw ArgumentError('atsign is required in activation string');
    }

    // parse from arg parser results
    final keyfile = results['target-keyfile'] as String?;

    return ActivateParams(
      atsign: atsign,
      type: type,
      cramSecret: _parseCramSecret(activationString),
      otp: _parseOtp(activationString),
      deviceName: _parseDeviceName(activationString),
      atKeysFilePath: keyfile,
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
    final regex = type == ActivateType.cram
        ? ActivateRegex.cram
        : ActivateRegex.enroll;

    final match = regex.firstMatch(input);
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
}

class ActivateRegex {
  // CRAM authentication: <atsign>:cram:<secret>
  static final cram = RegExp(r'^(?<atsign>[^:]+):cram:(?<secret>.+)$');

  // Enrollment: <atsign>:enroll:otp:<otp>[:name:<device>]
  static final enroll = RegExp(
    r'^(?<atsign>[^:]+):enroll:otp:(?<otp>[A-Za-z0-9]{6})'
    r'(?::name:(?<device_name>[^]+))?$', // ?: indicates a non-capturing group
  );
}

/// Named capture groups used in [ActivateRegex]
class ActivateRegexGroups {
  static const atsign = 'atsign';
  static const cram = 'secret';
  static const otp = 'otp';
  static const deviceName = 'device_name';
  static const keyfilePath = 'keyfile_path';
}
