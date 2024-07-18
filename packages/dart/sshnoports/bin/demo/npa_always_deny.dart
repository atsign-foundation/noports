import 'dart:async';
import 'package:noports_core/npa.dart';
import 'package:sshnoports/npa_bootstrapper.dart' as bootstrapper;

void main(List<String> args) async {
  await bootstrapper.run(AlwaysDeny(), args);
}

class AlwaysDeny implements NPARequestHandler {
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
