import 'dart:async';
import 'dart:io';
import 'package:at_policy/at_policy.dart';
import 'package:noports_core/utils.dart';
import 'package:sshnoports/policy_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(CLI(), args);
}

class CLI implements PolicyRequestHandler {
  @override
  Future<PolicyResponse> doAuthCheck(PolicyRequest authCheckRequest) async {
    stdout.writeln('Received request: $authCheckRequest');
    stdout.write('(A)pprove or (D)eny? : ');
    String decision = '';
    while (decision.isEmpty) {
      decision = stdin.readLineSync()!;
    }
    final bool authorized = decision.toLowerCase().startsWith('a');
    if (authorized) {
      return PolicyResponse(
        message: 'Approved via CLI',
        policyInfos: [infoPermitOpen(['*:*'])],
      );
    } else {
      return PolicyResponse(
        message: 'Denied via CLI',
        policyInfos: [],
      );
    }
  }
}
