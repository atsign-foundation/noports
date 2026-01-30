import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';

class PolicyRequestHandler implements NPARequestHandler {
  final PolicyCache policyCache;

  PolicyRequestHandler({
    required this.policyCache
  });

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest authCheckRequest) async {
    final String clientAtSign = authCheckRequest.clientAtsign;
    final String daemonAtSign = authCheckRequest.daemonAtsign;
    final String deviceName = authCheckRequest.daemonDeviceName;
    final String deviceGroupName = authCheckRequest.daemonDeviceGroupName;

    final Set<ServiceACL> matchedServiceACLs = 
      policyCache.findMatchedServiceACLs(
        clientAtSign: clientAtSign,
        daemonAtSign: daemonAtSign,
        deviceName: deviceName,
        deviceGroupName: deviceGroupName);

    final List<String> permitOpens = [];
    for(final ServiceACL sacl in matchedServiceACLs) {
      permitOpens.add(sacl.permitOpen);
    }

    // authorized bool doesn't actually make sense
    // sshnpd's should be checking the permitOpens for when doing a true
    // policy check
    final bool authorized = permitOpens.isNotEmpty;

    NPAAuthCheckResponse response;
    if(authorized) {
      response = NPAAuthCheckResponse(
        authorized: true,
        message: '${authCheckRequest.clientAtsign} has permission'
            ' for device ${authCheckRequest.daemonDeviceName}'
            ' and/or device group ${authCheckRequest.daemonDeviceGroupName}'
            ' at daemon ${authCheckRequest.daemonAtsign}',
        permitOpen: permitOpens);
    } else {
      response = NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}'
            ' at ${authCheckRequest.daemonAtsign}'
            ' for either the device ${authCheckRequest.daemonDeviceName}'
            ' or the deviceGroup ${authCheckRequest.daemonDeviceGroupName}',
        permitOpen: permitOpens);
    }
    return response;

  }
}

class PolicyServiceDefaults {
  static const String baseNamespace = 'sshnp';
  static const String domainNamespace = 'npp';
}

class PolicyService {
  @override
  final AtClient atClient;
  @override
  final AtSignLogger logger = AtSignLogger('PolicyService');

  final PolicyCache policyCache;
  final PolicyOperationHooks? policyOperationHooks;

  // services
  late NPA npa; // responds to policy requests
  late AtRpc managerRpcListener; // policy api (put/get)
  late AtRpc pingRpcListener; // ping API

  final Set<String> managerAllowList; // set of atSigns who can talk to policy manager api rpc (put/get policy rules)

  PolicyService({
    // mandatroy
    required this.atClient,
    required this.policyCache,
    required this.managerAllowList,
    required String binariesVersion,
    // optional
    final String domainNamespace = PolicyServiceDefaults.domainNamespace,
    final String baseNamespace = PolicyServiceDefaults.baseNamespace,
    final String? eventLoggingAtSign,
    this.policyOperationHooks,
    String? homeDirectory,
  }) {
    if(homeDirectory == null) {
      homeDirectory = getHomeDirectory();
      if(homeDirectory == null) {
        throw Exception('Home directory could not be resolved.');
      }
    }

    // RPC for handling incoming policy detail requests
    npa = NPAImpl(
      handler: PolicyRequestHandler(policyCache: policyCache),
      atClient: atClient,
      homeDirectory: homeDirectory,
      eventLoggingAtsign: eventLoggingAtSign as Atsign?);

    // RPC for handling other v2 policy operations
    managerRpcListener = AtRpc(
      atClient: atClient,
      callbacks: ManagerRpcCallbacks(
        atClient: atClient,
        policyCache: policyCache,
        policyOperationHooks: policyOperationHooks,
        binariesVersion: binariesVersion,
      ),
      isClient: false,
      isServer: true,
      allowAll: false, // people not on the managerAllowList should not be allowed to change policy rules
      allowList: managerAllowList,
      baseNameSpace: baseNamespace,
      domainNameSpace: domainNamespace);
    
    pingRpcListener = AtRpc(
      atClient: atClient,
      callbacks: PingRpcCallbacks(binariesVersion: binariesVersion),
      isClient: false,
      isServer: true,
      allowAll: false, // only people on the managerAllowList can ping (prevents version info leakage)
      allowList: managerAllowList,
      baseNameSpace: baseNamespace,
      domainNameSpace: 'ping');
  }

  Future<void> start() async {
    await npa.run();
    managerRpcListener.start();
    pingRpcListener.start();
  }
}

