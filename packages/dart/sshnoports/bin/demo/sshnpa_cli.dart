import 'dart:async';
import 'dart:io';
import 'package:noports_core/sshnpa.dart';
import 'package:sshnoports/sshnpa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(CLI(), args);
}

class CLI implements SSHNPARequestHandler {
  @override
  Future<SSHNPAAuthCheckResponse> doAuthCheck(
      SSHNPAAuthCheckRequest authCheckRequest) async {
    stdout.writeln('Received request: $authCheckRequest');
    stdout.write('(A)pprove or (D)eny? : ');
    String decision = '';
    while (decision.isEmpty) {
      decision = stdin.readLineSync()!;
    }
    final bool authorized = decision.toLowerCase().startsWith('a');
    return SSHNPAAuthCheckResponse(
        authorized: authorized,
        message: authorized ? 'Approved via CLI' : 'Denied via CLI',
    );
  }
}
