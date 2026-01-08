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

  Future<void> init({final String? homeDirectory}) async {
    cache = PolicyCache();

    final String? homeDir = homeDirectory ?? getHomeDirectory();
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
    final Map<String, dynamic> requestPayload = request.payload;
    final Map<String, dynamic> responsePayload = {};
    if(!requestPayload.containsKey('operation') || !requestPayload.containsKey('target') || !requestPayload.containsKey('value')) {
      return AtRpcResp(reqId: reqId, respType: AtRpcRespType.error, message: 'operation, target, or value JSON keys was not found in the payload.', payload: {});
    }
    final String operation = requestPayload['operation'];
    final String target = requestPayload['target'];
    final Map<String, dynamic> valueAsMap = requestPayload['value'];
    late String message;
    late bool success; 
    switch(operation) {
      case 'get':
        switch(target) {
          case 'allClients': {
            final Set<Client> clients = cache.clients;
            final Set<Map<String, dynamic>> clientsAsJson = clients.map((client) => client.toJson()).toSet();
            final int amount = clientsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['value'] = clientsAsJson;
            message = '$amount Clients found.';
            success = true;
            break;
          }
          case 'allClientGroups': {
            final Set<ClientGroup> clientGroups = cache.clientGroups;
            final Set<Map<String, dynamic>> clientGroupsAsJson = clientGroups.map((clientGroup) => clientGroup.toJson()).toSet();
            final int amount = clientGroups.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupsAsJson;
            message = '$amount ClientGroups found.';
            break;
          }
          case 'allClientGroupMembers': {
            final Set<ClientGroupMember> clientGroupMembers = cache.clientGroupMembers;
            final Set<Map<String, dynamic>> clientGroupMembersAsJson = clientGroupMembers.map((clientGroupMember) => clientGroupMember.toJson()).toSet();
            final int amount = clientGroupMembersAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupMembersAsJson;
            message = '$amount ClientGroupMembers found.';
            success = true;
            break;
          }
          case 'allDaemons': {
            final Set<Daemon> daemons = cache.daemons;
            final Set<Map<String, dynamic>> daemonsAsJson = daemons.map((daemon) => daemon.toJson()).toSet();
            final int amount = daemonsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = daemonsAsJson;
            message = '$amount daemons found.';
            success = true;
            break;
          }
          case 'allServices': {
            final Set<Service> services = cache.services;
            final Set<Map<String, dynamic>> servicesAsJson = services.map((service) => service.toJson()).toSet();
            final int amount = servicesAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = servicesAsJson;
            message = '$amount services found.';
            success = true;
            break;
          }
          case 'allServiceACLs': {
            final Set<ServiceACL> serviceACLs = cache.serviceACLs;
            final Set<Map<String, dynamic>> serviceACLsAsJson = serviceACLs.map((serviceACL) => serviceACL.toJson()).toSet();
            final int amount = serviceACLsAsJson.length;
            responsePayload['amount'] = serviceACLsAsJson.length;
            responsePayload['list'] = serviceACLsAsJson;
            message = '$amount ServiceACLs found.';
            success = true;
            break;
          }
          default: {
            break;
          }
        }
        break;  
      case 'put':
        switch(target) {
          case 'Client': {
            final Client client = Client.fromJson(valueAsMap);
            cache.putClient(client);
            responsePayload['clientId'] = cache.getClientById(client.id!);
            success = true;
            message = 'Client stored successfully.';
            break;
          }
          case 'ClientGroup': {
            final ClientGroup clientGroup = ClientGroup.fromJson(valueAsMap);
            cache.putClientGroup(clientGroup);
            responsePayload['clientGroupId'] = cache.getClientGroupById(clientGroup.id!);
            success = true;
            message = 'Client group stored successfully.';
            break;
          }
          case 'ClientGroupMember': {
            final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(valueAsMap);
            cache.putClientGroupMember(clientGroupMember);
            responsePayload['clientGroupMemberId'] = cache.getClientGroupMemberById(clientGroupMember.id!);
            success = true;
            message = 'Client group member stored successfully.';
            break;
          }
          case 'Daemon': {
            final Daemon daemon = Daemon.fromJson(valueAsMap);
            cache.putDaemon(daemon);
            responsePayload['daemonId'] = cache.getDaemonById(daemon.id!);
            success = true;
            message = 'Daemon stored successfully.';
            break;
          }
          case 'Service': {
            final Service service = Service.fromJson(valueAsMap);
            cache.putService(service);
            responsePayload['serviceId'] = cache.getServiceById(service.id!);
            success = true;
            message = 'Service stored successfully.';
            break;
          }
          case 'ServiceACL': {
            final ServiceACL serviceACL = ServiceACL.fromJson(valueAsMap);
            cache.putServiceACL(serviceACL);
            responsePayload['serviceACLId'] = cache.getServiceACLById(serviceACL.id!);
            success = true;
            message = 'Service ACL stored successfully.';
            break;
          }
          default: {
            success = false;
            message = 'Unknown target for put operation: $target';
            break;
          }
        }
        break;
      default:
        success = false;
        message = 'Unknown operation: $operation';
        break;
    }
    return AtRpcResp(reqId: reqId, payload: responsePayload, message: message, respType: success ? AtRpcRespType.success : AtRpcRespType.error);
  }

  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError(); 
  }

}

