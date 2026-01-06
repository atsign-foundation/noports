import 'dart:convert';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/admin_v2.dart';
import 'package:noports_core/npa.dart';

// *.client.policy.sshnp --> a client (e.g. "@colin", "Colin")
// *.client_group.policy.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
// *.client_group_members.policy.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
// *.daemon.policy.sshnp --> a daemon (e.g. "@device")
// *.service.policy.sshnp --> a device (e.g. daemon.id, "deviceName")
// *.service_acl.policy.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")

class PolicyRequestHandler implements NPARequestHandler {
  final PolicyCache policyCache;

  PolicyRequestHandler(this.policyCache);

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest authCheckRequest) async {
    final String clientAtSign = authCheckRequest.clientAtsign;
    final String daemonAtSign = authCheckRequest.daemonAtsign;
    final String deviceName = authCheckRequest.daemonDeviceName;
    final String deviceGroupName = authCheckRequest.daemonDeviceGroupName;

    final Set<ServiceACL> matchedServiceACLs = policyCache.findMatchedServiceACLs(clientAtSign: clientAtSign, daemonAtSign: daemonAtSign, deviceName: deviceName, deviceGroupName: deviceGroupName);

    final List<String> permitOpens = [];
    for(final ServiceACL sacl in matchedServiceACLs) {
    permitOpens.add(sacl.permitOpen);
  }

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

class PolicyService with AtClientBindings implements AtRpcCallbacks  {
  @override
  final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('PolicyService');

  late PolicyCache cache;
  late NPA npa;
  late AtRpc rpcListener;

  PolicyService({required this.atClient});

  Future<void> init() async {
    cache = PolicyCache();

    final String? homeDir = getHomeDirectory();
    if(homeDir == null) {
      throw Exception('Home directory not found.');
    }

    // RPC for handling incoming policy detail requests
    npa = NPAImpl(
      handler: PolicyRequestHandler(cache),
      atClient: atClient,
      homeDirectory: homeDir,
      eventLoggingAtsign: null);

    // RPC for handling other v2 policy operations
    rpcListener = AtRpc(atClient: atClient,
      callbacks: this,
      isClient: false,
      isServer: true,
      allowAll: true,
      allowList: {atClient.getCurrentAtSign()!}, // for now, only the policy service atSign will be allowed to modify policy data
      baseNameSpace: 'sshnp',
      domainNameSpace: 'policy');
  }

  Future<void> start() async {
    await npa.run();
    rpcListener.start();
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    final int reqId = request.reqId;
    if(fromAtSign != atClient.getCurrentAtSign()) {
      return AtRpcResp(reqId: reqId, respType: AtRpcRespType.error, message: 'Unauthorized atSign', payload: {'success': false});
    }
    final Map<String, dynamic> payload = request.payload;
    final Map<String, dynamic> response = {
    'success': false,
    'message': 'Default message',
  };
    if(!payload.containsKey('operation') || !payload.containsKey('target') || !payload.containsKey('value')) {
      return AtRpcResp(reqId: reqId, respType: AtRpcRespType.error, message: 'operation, target, or value JSON keys was not found in the payload.', payload: {'success': false});
    }
    final String operation = payload['operation'];
    final String target = payload['target'];
    final Map<String, dynamic> value = jsonDecode(payload['value']);
    switch(operation) {
      case 'get':
        switch(target) {
          case 'allClients': {
            final Set<Client> clients = cache.clients;
            List<String> clientsAsJsonStrings = [];
            for(final Client client in clients) {
              clientsAsJsonStrings.add(jsonEncode(client.toJson()));
            }
            final int amount = clients.length;
            response['success'] = true;
            response['message'] = '$amount clients found.';
            response['value'] = clientsAsJsonStrings;
            break;
          }
          case 'allClientGroups': {
            final Set<ClientGroup> clientGroups = cache.clientGroups;
            List<String> clientGroupsAsJsonStrings = [];
            for(final ClientGroup clientGroup in clientGroups) {
              clientGroupsAsJsonStrings.add(jsonEncode(clientGroup.toJson()));
            }
            final int amount = clientGroups.length;
            response['success'] = true;
            response['message'] = '$amount client groups found.';
            response['value'] = clientGroupsAsJsonStrings;
            break;
          }
          case 'allClientGroupMembers': {
            final Set<ClientGroupMember> clientGroupMembers = cache.clientGroupMembers;
            List<String> clientGroupMembersAsJsonStrings = [];
            for(final ClientGroupMember clientGroupMember in clientGroupMembers) {
              clientGroupMembersAsJsonStrings.add(jsonEncode(clientGroupMember.toJson()));
            }
            final int amount = clientGroupMembers.length;
            response['success'] = true;
            response['message'] = '$amount client group members found.';
            response['value'] = clientGroupMembersAsJsonStrings;
            break;
          }
          case 'allDaemons': {
            final Set<Daemon> daemons = cache.daemons;
            List<String> daemonsAsJsonStrings = [];
            for(final Daemon daemon in daemons) {
            daemonsAsJsonStrings.add(jsonEncode(daemon.toJson()));
          }
            final int amount = daemons.length;
            response['success'] = true;
            response['message'] = '$amount daemons found.';
            response['value'] = daemonsAsJsonStrings;
            break;
          }
          case 'allServices': {
            final Set<Service> services = cache.services;
            List<String> servicesAsJsonStrings = [];
            for(final Service service in services) {
            servicesAsJsonStrings.add(jsonEncode(service.toJson()));
          }
            final int amount = services.length;
            response['success'] = true;
            response['message'] = '$amount services found.';
            response['value'] = servicesAsJsonStrings;
            break;
          }
          case 'allServiceACLs': {
            final Set<ServiceACL> serviceACLs = cache.serviceACLs;
            List<String> serviceACLsAsJsonStrings = [];
            for(final ServiceACL serviceACL in serviceACLs) {
            serviceACLsAsJsonStrings.add(jsonEncode(serviceACL.toJson()));
          }
            final int amount = serviceACLs.length;
            response['success'] = true;
            response['message'] = '$amount service ACLs found.';
            response['value'] = serviceACLsAsJsonStrings;
            break;
          }
          default: {
            response['success'] = false;
            response['message'] = 'Unknown operation: $operation';
          }
        }
        break;  
      case 'put':
        switch(target) {
          case 'Client': {
            final Client client = Client.fromJson(value);
            cache.putClient(client);
            response['success'] = true;
            response['message'] = 'Client stored successfully.';
            response['value'] = cache.getClientById(client.id!);
            break;
          }
          case 'ClientGroup': {
            final ClientGroup clientGroup = ClientGroup.fromJson(value);
            cache.putClientGroup(clientGroup);
            response['success'] = true;
            response['message'] = 'Client group stored successfully.';
            response['value'] = cache.getClientGroupById(clientGroup.id!);
            break;
          }
          case 'ClientGroupMember': {
            final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(value);
            cache.putClientGroupMember(clientGroupMember);
            response['success'] = true;
            response['message'] = 'Client group member stored successfully.';
            response['value'] = cache.getClientGroupMemberById(clientGroupMember.id!);
            break;
          }
          case 'Daemon': {
            final Daemon daemon = Daemon.fromJson(value);
            cache.putDaemon(daemon);
            response['success'] = true;
            response['message'] = 'Daemon stored successfully.';
            response['value'] = cache.getDaemonById(daemon.id!);
            break;
          }
          case 'Service': {
            final Service service = Service.fromJson(value);
            cache.putService(service);
            response['success'] = true;
            response['message'] = 'Service stored successfully.';
            response['value'] = cache.getServiceById(service.id!);
            break;
          }
          case 'ServiceACL': {
            final ServiceACL serviceACL = ServiceACL.fromJson(value);
            cache.putServiceACL(serviceACL);
            response['success'] = true;
            response['message'] = 'Service ACL stored successfully.';
            response['value'] = cache.getServiceACLById(serviceACL.id!);
            break;
          }
          default: {
            response['success'] = false;
            response['message'] = 'Unknown target for put operation: $target';
            response['value'] = {};
            break;
          }
        }
        break;
      default:
        response['success'] = false;
        response['message'] = 'Unknown operation: $operation';
        break;
    }
    return AtRpcResp(reqId: reqId, payload: response, message: response['message'], respType: response['success'] ? AtRpcRespType.success : AtRpcRespType.error);
  }

  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError(); 
  }

}

