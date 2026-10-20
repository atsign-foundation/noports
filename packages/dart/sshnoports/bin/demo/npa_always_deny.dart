import 'dart:async';
import 'package:at_client/at_client.dart' show Atsign;
import 'package:noports_core/npa.dart';
import 'package:sshnoports/npa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(AlwaysDeny(), args);
}

class AlwaysDeny implements NPARequestHandler {
  @override
  bool hasRulesFor(Atsign daemonAtsign) => true;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(
      NPAAuthCheckRequest authCheckRequest) async {
    return NPAAuthCheckResponse(
      authorized: false,
      message: 'Computer says "Noooo..."',
      permitOpen: [],
    );
  }
}
