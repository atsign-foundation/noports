import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/version.dart' as core_version;

/// Callbacks for handling ping RPC requests to the policy service
class PingRpcCallbacks implements AtRpcCallbacks {
  final AtSignLogger logger = AtSignLogger('PingRpcCallbacks');
  final String? binariesVersion;

  PingRpcCallbacks({this.binariesVersion});

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    logger.info('Received ping request from $fromAtSign');

    final Map<String, dynamic> payload = {
      'status': 'alive',
      'coreVersion': core_version.packageVersion,
      'features': [
        'policyManagement',
        'authorizationCheck',
        'clientManagement',
        'daemonManagement',
        'serviceACL',
        'policyHooks'
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add binariesVersion if provided
    if (binariesVersion != null) {
      payload['binariesVersion'] = binariesVersion;
    }

    return AtRpcResp(
      reqId: request.reqId,
      respType: AtRpcRespType.success,
      message: 'pong',
      payload: payload,
    );
  }

  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError('PingRpcCallbacks only receives requests, does not send them');
  }
}
