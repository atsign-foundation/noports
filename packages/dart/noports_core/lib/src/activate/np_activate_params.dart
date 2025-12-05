import 'package:at_utils/at_utils.dart';
import 'package:noports_core/src/activate/utils/constants.dart';
import 'package:noports_core/src/activate/utils/console.dart';
import 'package:noports_core/src/activate/utils/regex.dart';

class NPActivateParams {
  late String atsign;

  String? cram;
  String? otp;
  String? atKeysFilePath;
  String? deviceName;
  String appName = defaultAppName;
  Map<String, String> namespaces = defaultEnrollmentNamespaces;
  bool showHelp;

  NPActivateParams({
    required this.atsign,
    this.cram,
    this.atKeysFilePath,
    this.otp,
    this.deviceName,
    this.showHelp = false,
  });

  factory NPActivateParams.fromArgs(List<String> args) {
    String authStr = args.first;

    return NPActivateParams(
        atsign: _parseAtsign(authStr),
        atKeysFilePath: _parseKeyfilePath(authStr),
        cram: _parseCram(authStr),
        otp: _parseOtp(authStr),
        deviceName: _parseDeviceName(authStr),
        showHelp: isHelpFlag(args[0]));
  }

  factory NPActivateParams.fromJson(Map<String, dynamic> json) {
    return NPActivateParams(
        atsign: json['atsign'],
        cram: json['cram'],
        otp: json['otp'],
        atKeysFilePath: json['atKeysFilePath'],
        deviceName: json['deviceName']);
    // does NOT parse appName and namespaces as they only use default values
  }

  static String _parseAtsign(String authStr, {String? regex}) {
    if (regex != null) {
      RegExpMatch? match = RegExp(regex).firstMatch(authStr);

      final atsign = match?.namedGroup(ActivateRegexGroups.atsign);
      if (atsign == null) {
        throw ArgumentError('Could not parse atsign from: $authStr');
      }
    }
    String atsign = authStr.split(':').first;
    return AtUtils.fixAtSign(atsign);
  }

  static String? _parseCram(String authStr) {
    final match = ActivateRegex.cram.firstMatch(authStr);
    final cram = match?.namedGroup(ActivateRegexGroups.cram);
    return cram;
  }

  static String? _parseOtp(String authStr) {
    final match = ActivateRegex.enroll.firstMatch(authStr);
    final otp = match?.namedGroup(ActivateRegexGroups.otp);
    return otp;
  }

  static String? _parseKeyfilePath(String authStr) {
    final match = ActivateRegex.enroll.firstMatch(authStr);
    final keyfilePath = match?.namedGroup(ActivateRegexGroups.keyfilePath);
    return keyfilePath;
  }

  static String? _parseDeviceName(String authStr) {
    final match = ActivateRegex.enroll.firstMatch(authStr);
    final deviceName = match?.namedGroup(ActivateRegexGroups.deviceName);
    return deviceName;
  }

  Map<String, String?> toJson() {
    return {
      'atsign': atsign,
      'cram': cram,
      'otp': otp,
      'atKeysFilePath': atKeysFilePath,
      'deviceName': deviceName
    };
  }
}
