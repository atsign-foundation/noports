import 'dart:async';
import 'package:at_policy/at_policy.dart';
import 'package:sshnoports/policy_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(AlwaysDeny(), args);
}

class AlwaysDeny implements PolicyRequestHandler {
  @override
  Future<PolicyResponse> doAuthCheck(PolicyRequest authCheckRequest) async {
    return PolicyResponse(
      message: 'Computer says "Noooo..."',
      policyInfos: [],
    );
  }
}
