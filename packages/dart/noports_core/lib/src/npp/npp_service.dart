import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';

class NppRequestHandler implements NPARequestHandler {
  final NppCache nppCache;

  NppRequestHandler({
    required this.nppCache
  });

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest authCheckRequest) async {
    final String clientAtSign = authCheckRequest.clientAtsign;
    final String daemonAtSign = authCheckRequest.daemonAtsign;
    final String deviceName = authCheckRequest.daemonDeviceName;
    final String deviceGroupName = authCheckRequest.daemonDeviceGroupName;

    final Set<ServiceACL> matchedServiceACLs =
      nppCache.findMatchedServiceACLs(
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

class NppServiceDefaults {
  static const String baseNamespace = 'sshnp';
  static const String domainNamespace = 'npp';
}

class NppService {
  // mandatory
  final AtClient atClient;
  final NppCache nppCache;
  final Set<String> managerAllowList; // set of atSigns who can talk to policy manager api rpc (put/get policy rules)
  final String binariesVersion;

  // optional
  final String? eventLoggingAtSign;
  final String baseNamespace;
  final String domainNamespace;
  final String? homeDirectory;
  final NppOperationHooks? nppOperationHooks;

  // instantiated from init()
  late NPA npa; // responds to policy requests
  late AtRpc managerRpcListener; // policy api (put/get/delete/ping)

  NppService({
    required this.atClient,
    required this.nppCache,
    required this.managerAllowList,
    required this.binariesVersion,
    this.eventLoggingAtSign,
    this.baseNamespace = NppServiceDefaults.baseNamespace,
    this.domainNamespace = NppServiceDefaults.domainNamespace,
    this.homeDirectory,
    this.nppOperationHooks,
  });

  void init() {
    String? homeDir = homeDirectory;
    if(homeDir == null) {
      homeDir = getHomeDirectory();
      if(homeDir == null) {
        throw Exception('Home directory could not be resolved.');
      }
    }
    final handler = NppRequestHandler(nppCache: nppCache);
    npa = NPAImpl(
      handler: handler,
      atClient: atClient,
      homeDirectory: homeDir,
      eventLoggingAtsign: eventLoggingAtSign as Atsign?);

    managerRpcListener = AtRpc(
      atClient: atClient,
      callbacks: ManagerRpcCallbacks(
        atClient: atClient,
        nppCache: nppCache,
        nppOperationHooks: nppOperationHooks,
        binariesVersion: binariesVersion,
        handler: handler,
      ),
      isClient: false,
      isServer: true,
      allowAll: false, // people not on the managerAllowList should not be allowed to change policy rules
      allowList: managerAllowList,
      baseNameSpace: baseNamespace,
      domainNameSpace: domainNamespace);
  }

  Future<void> start() async {
    await npa.run();
    managerRpcListener.start();
  }
}
