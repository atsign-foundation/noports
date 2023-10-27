import 'dart:async';
import 'package:noports_core/sshnpa.dart';
import 'package:sshnoports/sshnpa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(AlwaysApproveHandler(), args);
}

class AlwaysApproveHandler implements SSHNPARequestHandler {
  @override
  Future<SSHNPAAuthCheckResponse> handleRequest(SSHNPAAuthCheckRequest authCheckRequest) async {
    return SSHNPAAuthCheckResponse(authorized: true, message: 'Heck yeah');
  }

}