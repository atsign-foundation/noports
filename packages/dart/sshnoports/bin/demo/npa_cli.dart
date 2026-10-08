import 'dart:async';
import 'dart:io';
import 'package:noports_core/npa.dart';
import 'package:sshnoports/npa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(CLI(), args);
}

class CLI implements NPARequestHandler {
  @override
  Future<NPAAuthCheckResponse> doAuthCheck(
      NPAAuthCheckRequest authCheckRequest) async {
    stdout.writeln('Received request: $authCheckRequest');
    stdout.write('(A)pprove or (D)eny? : ');
    String decision = '';
    while (decision.isEmpty) {
      decision = stdin.readLineSync()!;
    }
    final bool authorized = decision.toLowerCase().startsWith('a');
    if (authorized) {
      return NPAAuthCheckResponse(
        authorized: true,
        message: 'Approved via CLI',
        permitOpen: ['*:*'],
      );
    } else {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'Denied via CLI',
        permitOpen: [],
      );
    }
  }
}
