import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/sshnpa/sshnpa_params.dart';
import 'package:noports_core/src/sshnpa/sshnpa_impl.dart';
import 'package:noports_core/src/sshnpa/sshnpa_rpcs.dart';

abstract class SSHNPARequestHandler {
  Future<SSHNPAAuthCheckResponse> handleRequest(SSHNPAAuthCheckRequest authCheckRequest);
}

/// - Listens for authorization check requests from sshnp daemons
/// - Checks if the clientAtSign is currently authorized to access
///   the sshnpd atSign and device
/// - Responds accordingly
abstract class SSHNPA implements AtRpcCallbacks {
  abstract final AtSignLogger logger;

  /// The [AtClient] used to communicate with SSHNPDs
  abstract AtClient atClient;

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The home directory on this host
  abstract final String homeDirectory;

  String get authorizerAtsign;

  abstract Set<String> daemonAtsigns;

  abstract SSHNPARequestHandler handler;

  static Future<SSHNPA> fromCommandLineArgs(List<String> args,
      {required SSHNPARequestHandler handler,
      AtClient? atClient,
      FutureOr<AtClient> Function(SSHNPAParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    return SSHNPAImpl.fromCommandLineArgs(
      args,
      handler: handler,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
      usageCallback: usageCallback,
    );
  }

  /// Starts the sshnpa service
  Future<void> run();
}
