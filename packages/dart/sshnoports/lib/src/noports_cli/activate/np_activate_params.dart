import 'package:sshnoports/src/noports_cli/util/constants.dart';
import 'package:sshnoports/src/noports_cli/util/regex.dart';

class NoportsParams {
  late String atsign;

  String? cram;
  String? otp;
  String? atKeysFilePath;
  String? deviceName;
  String appName = defaultAppName;
  Map<String, String> namespaces = defaultEnrollmentNamespaces;

  NoportsParams({
    required this.atsign,
    this.cram,
    this.atKeysFilePath,
    this.otp,
    this.deviceName,
  });

  factory NoportsParams.fromArgs(List<String> args) {
    String authStr = args[1];

    return NoportsParams(
        atsign: _parseAtsign(authStr),
        atKeysFilePath: _parseKeyfilePath(authStr),
        cram: _parseCram(authStr),
        otp: _parseOtp(authStr),
        deviceName: _parseDeviceName(authStr));
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
    return atsign;
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
}
