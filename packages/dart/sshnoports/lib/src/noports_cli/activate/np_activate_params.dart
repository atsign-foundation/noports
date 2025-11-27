import 'package:at_utils/at_utils.dart';
import 'package:sshnoports/src/noports_cli/util/constants.dart';
import 'package:sshnoports/src/noports_cli/util/np_utils.dart';
import 'package:sshnoports/src/noports_cli/util/regex.dart';

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
        showHelp: hasHelpFlag(args));
  }

  factory NPActivateParams.fromJson(Map<String, dynamic> json) {
    return NPActivateParams(
        atsign: json['atsign'],
        cram: json['cram'],
        otp: json['otp'],
        atKeysFilePath: json['atKeysFilePath'],
        deviceName: json['deviceName']);
    // does NOT parse appName and namespaces as they are default
  }

  static String _parseAtsign(String authStr, {String? regex}) {
    if (regex != null) {
      RegExpMatch? match = RegExp(regex).firstMatch(authStr);

      final atsign = match?.namedGroup(RegexGroupNames.atsign);
      if (atsign == null) {
        throw ArgumentError('Could not parse atsign from: $authStr');
      }
    }
    String atsign = authStr.split(':').first;
    return AtUtils.fixAtSign(atsign);
  }

  static String? _parseCram(String authStr) {
    final match = RegExp(cramRegex).firstMatch(authStr);
    final cram = match?.namedGroup(RegexGroupNames.cram);
    return cram;
  }

  static String? _parseOtp(String authStr) {
    final match = RegExp(enrollRegex).firstMatch(authStr);
    final otp = match?.namedGroup(RegexGroupNames.otp);
    return otp;
  }

  static String? _parseKeyfilePath(String authStr) {
    final match = RegExp(enrollRegex).firstMatch(authStr);
    final keyfilePath = match?.namedGroup(RegexGroupNames.keyfilePath);
    return keyfilePath;
  }

  static String? _parseDeviceName(String authStr) {
    final match = RegExp(enrollRegex).firstMatch(authStr);
    final deviceName = match?.namedGroup(RegexGroupNames.device);
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
