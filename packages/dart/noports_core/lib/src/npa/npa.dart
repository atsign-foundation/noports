import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/npa/npa_params.dart';
import 'package:noports_core/src/npa/npa_impl.dart';
import 'package:noports_core/src/npa/npa_rpcs.dart';

abstract class NPARequestHandler {
  Future<NPAAuthCheckResponse> doAuthCheck(
    NPAAuthCheckRequest authCheckRequest,
  );
}

/// - Listens for authorization check requests from sshnp daemons
/// - Checks if the clientAtSign is currently authorized to access
///   the sshnpd atSign and device
/// - Responds accordingly
abstract class NPA {
  abstract final AtSignLogger logger;

  /// The [AtClient] used to communicate with SSHNPDs
  abstract AtClient atClient;

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The home directory on this host
  abstract final String homeDirectory;

  /// Policy service's atSign
  Atsign get policyAtsign;

  /// atSign to which we will send noports session logging events
  Atsign? get eventLoggingAtsign;

  NPARequestHandler get handler;

  static Future<NPA> fromCommandLineArgs(
    List<String> args, {
    required NPARequestHandler handler,
    AtClient? atClient,
    FutureOr<AtClient> Function(NPAParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) async {
    return NPAImpl.fromCommandLineArgs(
      args,
      handler: handler,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
      usageCallback: usageCallback,
      helpCallback: helpCallback,
      versionCallback: versionCallback,
    );
  }

  /// Starts the sshnpa service
  Future<void> run();
}
