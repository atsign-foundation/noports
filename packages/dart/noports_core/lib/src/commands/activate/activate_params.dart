import 'package:args/args.dart';
import 'package:at_commons/atsign.dart';
import 'package:noports_core/commands.dart';
import 'package:noports_core/src/commands/utils/constants.dart';
import 'package:noports_core/src/commands/utils/regex.dart';

enum ActivateType {
  cram,
  enroll;

  static ActivateType parse(String input) {
    try {
      return values.firstWhere((type) => input.contains(type.name));
    } on Exception {
      throw ArgumentError(
        'Invalid activation type in: $input (expected "cram" or "enroll")',
      );
    }
  }
}

class ActivateParams {
  final String atsign;
  final ActivateType type;
  final String? cramSecret;
  final String? otp;
  final String? deviceName;

  String? atKeysFilePath;
  String appName = defaultAppName;
  Map<String, String> namespaces = defaultEnrollmentNamespaces;

  // Static parser for consistent usage and help generation
  static final ArgParser argParser = _createArgParser();

  ActivateParams({
    required this.atsign,
    required this.type,
    this.cramSecret,
    this.otp,
    this.deviceName,
    this.atKeysFilePath,
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
    );
  }

  
  static ArgParser _createArgParser() {
    return ArgParser()
      ..addOption(
        'target-keyfile',
        abbr: 't',
        mandatory: false,
        help: 'Destination path for atKeys file',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show this usage info',
      );
  }

  static String? _parseAtsign(String input, ActivateType type) {
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

  Map<String, String?> toJson() {
    return {
      'atsign': atsign,
      'cramSecret': cramSecret,
      'otp': otp,
      'deviceName': deviceName,
      'atKeysFilePath': atKeysFilePath,
    };
  }
}
