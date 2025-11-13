import 'package:sshnoports/src/noports_cli/util/constants.dart';
import 'package:sshnoports/src/noports_cli/util/regex.dart';

class NoportsParams {
  late String atsign;

  String? cram;
  String? otp;
  String? atKeysFilePath;
  String? deviceName;
  String appName = 'noports';
  Map<String, String> namespaces = {
    "sshnp": "rw",
    "sshrvd": "rw",
    "noports": "rw",
  };

  NoportsParams({
    required this.atsign,
    this.cram,
    this.atKeysFilePath,
    this.otp,
    this.deviceName,
  });

  factory NoportsParams.fromArgs(List<String> args) {
    String authString = args[1];

    final atsign = _parseAtsign(authString);
    final atKeysFilePath = _parseKeyfilePath(authString);
    final cram = _parseCram(authString);
    final otp = _parseOtp(authString);
    final deviceName = _parseDeviceName(authString);

    return NoportsParams(
        atsign: atsign,
        atKeysFilePath: atKeysFilePath,
        cram: cram,
        otp: otp,
        deviceName: deviceName);
  }

  static String _parseAtsign(String rawInput) {
    // RegExpMatch? match;
    // switch (activateCommand) {
    //   case NPActivateType.cram:
    //     match = RegExp(cramRegex).firstMatch(rawInput);
    //     break;
    //   case NPActivateType.enroll:
    //     match = RegExp(enrollRegex).firstMatch(rawInput);
    //     break;
    // }
    //
    // final atsign = match?.namedGroup(RegexGroupNames.atsign);
    // if (atsign == null) {
    //   throw ArgumentError('Could not parse atsign from: $rawInput');
    // }
    String atsign = rawInput.split(':').first;
    return atsign;
  }

  static String? _parseCram(String rawInput) {
    final match = RegExp(cramRegex).firstMatch(rawInput);
    final cram = match?.namedGroup(RegexGroupNames.cram);
    return cram;
  }

  static String? _parseOtp(String rawInput) {
    final match = RegExp(enrollRegex).firstMatch(rawInput);
    final otp = match?.namedGroup(RegexGroupNames.otp);
    return otp;
  }

  static String? _parseKeyfilePath(String rawInput) {
    final match = RegExp(enrollRegex).firstMatch(rawInput);
    final keyfilePath = match?.namedGroup(RegexGroupNames.keyfilePath);
    return keyfilePath;
  }

  static String? _parseDeviceName(String rawInput) {
    final match = RegExp(enrollRegex).firstMatch(rawInput);
    final deviceName = match?.namedGroup(RegexGroupNames.device);
    return deviceName;
  }
}
