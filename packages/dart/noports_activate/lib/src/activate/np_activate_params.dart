import 'package:at_commons/at_commons.dart';
import 'package:noports_activate/src/noports_activate_cli.dart';
import 'package:noports_activate/src/activate/noports_activate_utils.dart';
import 'package:noports_activate/src/activate/np_activate.dart';

class NPActivateParams {
  NPActivateType? command;
  String? atsign;
  String? cram;
  String? otp;
  String? deviceName;

  NPActivateParams({
    this.command,
    this.atsign,
    this.cram,
    this.otp,
    this.deviceName,
  });

  String appName = 'noports';
  String deviceNamePrefix = 'noports_';
  Map<String, String> namespaces = {
    "sshnp": "rw",
    "sshrvd": "rw",
    "noports": "rw",
  };

  factory NPActivateParams.fromArgs(List<String> args) {
    NPActivateParams params = NPActivateParams();
    String authString = args[1];

    params.command = params._parseAuthType(authString);
    params.atsign = params._parseAtsign(authString, params.command);
    params.cram = params._parseCram(authString);
    params.otp = params._parseOtp(authString);
    // append otp to [deviceNamePrefix] to ensure unique device names
    params.deviceName = '${params.deviceNamePrefix}${params.otp}';

    return params;
  }

  NPActivateType _parseAuthType(String cmd) {
    if (cmd.contains('cram')) {
      return NPActivateType.cram;
    } else if (cmd.contains('enroll')) {
      return NPActivateType.enroll;
    }
    throw IllegalArgumentException('Invalid command: $cmd');
  }

  String _parseAtsign(String rawInput, NPActivateType? activateType) {
    RegExpMatch? match;
    switch (activateType) {
      case NPActivateType.cram:
        match = cramRegex.firstMatch(rawInput);
        break;
      case NPActivateType.enroll:
        match = enrollRegex.firstMatch(rawInput);
        break;
      default:
        throw IllegalArgumentException('Invalid command: $activateType');
    }

    final atsign = match?.namedGroup('atsign');
    if (atsign == null) {
      throw IllegalArgumentException('Could not parse atsign from: $rawInput');
    }
    return atsign;
  }

  String _parseCram(String rawInput) {
    final match = cramRegex.firstMatch(rawInput);
    final cram = match?.namedGroup('cram');
    if (cram == null) {
      throw IllegalArgumentException('Unable to parse cram from: $rawInput');
    }
    return cram;
  }

  String _parseOtp(String rawInput) {
    final match = enrollRegex.firstMatch(rawInput);
    final otp = match?.namedGroup('otp');
    if (otp == null) {
      throw IllegalArgumentException('Unable to parse otp from: $rawInput');
    }
    return otp;
  }
}
