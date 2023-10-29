import 'dart:async';
import 'package:noports_core/sshnpa.dart';
import 'package:sshnoports/sshnpa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(AlwaysDeny(), args);
}

class AlwaysDeny implements SSHNPARequestHandler {
  @override
  Future<SSHNPAAuthCheckResponse> doAuthCheck(SSHNPAAuthCheckRequest authCheckRequest) async {
    return SSHNPAAuthCheckResponse(authorized: false, message: 'Computer says "Noooo..."');
  }

}