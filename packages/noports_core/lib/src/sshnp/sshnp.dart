import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/sshnp_foundation.dart';

abstract interface class Sshnp {
  /// Legacy v3.x.x client
  factory Sshnp.unsigned({
    required AtClient atClient,
    required SshnpParams params,
  }) {
    return SshnpUnsignedImpl(atClient: atClient, params: params);
  }

  /// Think of this as the "default" client - calls /usr/bin/ssh
  factory Sshnp.execLocal({
    required AtClient atClient,
    required SshnpParams params,
  }) {
    return SshnpExecLocalImpl(atClient: atClient, params: params);
  }

  /// Uses a dartssh2 ssh client - still expects local ssh keys
  factory Sshnp.dartLocal({
    required AtClient atClient,
    required SshnpParams params,
  }) {
    return SshnpDartLocalImpl(atClient: atClient, params: params);
  }

  /// Uses a dartssh2 ssh client - requires that you pass in the identity keypair
  factory Sshnp.dartPure({
    required AtClient atClient,
    required SshnpParams params,
    required AtSshKeyPair? identityKeyPair,
  }) {
    var sshnp = SshnpDartPureImpl(
      atClient: atClient,
      params: params,
    );
    if (identityKeyPair != null) {
      sshnp.keyUtil.addKeyPair(
        keyPair: identityKeyPair,
        identifier: identityKeyPair.identifier,
      );
    }
    return sshnp;
  }

  /// The atClient to use for communicating with the atsign's secondary server
  AtClient get atClient;

  /// The parameters used to configure this SSHNP instance
  SshnpParams get params;

  /// May only be run after [initialize] has been run.
  /// - Sends request to sshnpd; the response listener was started by [initialize]
  /// - Waits for success or error response, or time out after 10 secs
  /// - If got a success response, print the ssh command to use to stdout
  /// - Clean up temporary files
  Future<SshnpResult> run();

  /// Send a ping out to all sshnpd and listen for heartbeats
  /// Returns two Iterable<String> and a Map<String, dynamic>:
  /// - Iterable<String> of atSigns of sshnpd that responded
  /// - Iterable<String> of atSigns of sshnpd that did not respond
  /// - Map<String, dynamic> where the keys are all atSigns included in the maps, and the values being their device info
  Future<SshnpDeviceList> listDevices();
}
