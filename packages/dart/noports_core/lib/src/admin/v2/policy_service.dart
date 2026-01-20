import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/admin_v2.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/src/admin/v2/policy_data_operation_hooks.dart';


class PolicyRequestHandler implements NPARequestHandler {
  final PolicyCache policyCache;

  PolicyRequestHandler(this.policyCache);

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
  static const String domainNamespace = 'policy_v2';
  static const String baseNamespace = 'sshnp';
}

class PolicyService with AtClientBindings implements AtRpcCallbacks  {
  @override
  final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('PolicyService');

  final PolicyCache policyCache;

  final PolicyOperationHooks? policyOperationHooks;

  // services
  late NPA npa; // responds to policy requests
  late AtRpc rpcListener; // policy api (put/get)

  final Set<String> allowList; // set of atSigns who can talk to policy api rpc (put/get policy rules)

  PolicyService({
    // mandatroy
    required this.atClient,
    required this.policyCache,
    required this.allowList,     // non-mandatory with defaults
    final String domainNamespace = PolicyServiceDefaults.domainNamespace,
    final String baseNamespace = PolicyServiceDefaults.baseNamespace,
    // optional
    String? homeDirectory,
    final String? eventLoggingAtSign,
    this.policyOperationHooks,
  }) {
    if(homeDirectory == null) {
      homeDirectory = getHomeDirectory();
      if(homeDirectory == null) {
        throw Exception('Home directory could not be resolved.');
      }
    }

    // RPC for handling incoming policy detail requests
    npa = NPAImpl(
      handler: PolicyRequestHandler(policyCache),
      atClient: atClient,
      homeDirectory: homeDirectory,
      eventLoggingAtsign: eventLoggingAtSign);

    // RPC for handling other v2 policy operations
    rpcListener = AtRpc(atClient: atClient,
      callbacks: this,
      isClient: false,
      isServer: true,
      allowAll: false, // people not on the allowList should not be allowed to change policy rules
      allowList: allowList, 
      baseNameSpace: baseNamespace,
      domainNameSpace: domainNamespace);
  }

  Future<void> start() async {
    await npa.run();
    rpcListener.start();
  }

  String _generateId(Set<PolicyEntry> entities) {
    int maxId = 0;
    for(final PolicyEntry entry in entities) {
      if(entry.id == null) {
        continue;
      }
      final int entryId = int.tryParse(entry.id!) ?? 0;
      if(entryId > maxId) {
        maxId = entryId;
      }
    }
    return (maxId + 1).toString();
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    final int reqId = request.reqId;
    if(fromAtSign != atClient.getCurrentAtSign()) {
      return AtRpcResp(reqId: reqId, respType: AtRpcRespType.error, message: 'Unauthorized atSign', payload: {'success': false});
    }
    final Map<String, dynamic> requestPayload = request.payload;
    final Map<String, dynamic> responsePayload = {};
    if(!requestPayload.containsKey('operation') ||
      !requestPayload.containsKey('target') ||
      !requestPayload.containsKey('value')) {
      return AtRpcResp(
        reqId: reqId,
        respType: AtRpcRespType.error,
        message: 'operation, target, or value JSON keys was not found in the '
          'payload.',
        payload: {});
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
            final Set<Client> clients = policyCache.clients;
            final Set<Map<String, dynamic>> clientsAsJson = clients.map((client) => client.toJson()).toSet();
            final int amount = clientsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientsAsJson.toList();
            message = '$amount Clients found.';
            success = true;
            break;
          }
          case 'allClientGroups': {
            final Set<ClientGroup> clientGroups = policyCache.clientGroups;
            final Set<Map<String, dynamic>> clientGroupsAsJson = clientGroups.map((clientGroup) => clientGroup.toJson()).toSet();
            final int amount = clientGroupsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupsAsJson.toList();
            message = '$amount ClientGroups found.';
            success = true;
            break;
          }
          case 'allClientGroupMembers': {
            final Set<ClientGroupMember> clientGroupMembers = policyCache.clientGroupMembers;
            final Set<Map<String, dynamic>> clientGroupMembersAsJson = clientGroupMembers.map((clientGroupMember) => clientGroupMember.toJson()).toSet();
            final int amount = clientGroupMembersAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupMembersAsJson.toList();
            message = '$amount ClientGroupMembers found.';
            success = true;
            break;
          }
          case 'allDaemons': {
            final Set<Daemon> daemons = policyCache.daemons;
            final Set<Map<String, dynamic>> daemonsAsJson = daemons.map((daemon) => daemon.toJson()).toSet();
            final int amount = daemonsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = daemonsAsJson.toList();
            message = '$amount daemons found.';
            success = true;
            break;
          }
          case 'allServices': {
            final Set<Service> services = policyCache.services;
            final Set<Map<String, dynamic>> servicesAsJson = services.map((service) => service.toJson()).toSet();
            final int amount = servicesAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = servicesAsJson.toList();
            message = '$amount services found.';
            success = true;
            break;
          }
          case 'allServiceACLs': {
            final Set<ServiceACL> serviceACLs = policyCache.serviceACLs;
            final Set<Map<String, dynamic>> serviceACLsAsJson = serviceACLs.map((serviceACL) => serviceACL.toJson()).toSet();
            final int amount = serviceACLsAsJson.length;
            responsePayload['amount'] = serviceACLsAsJson.length;
            responsePayload['list'] = serviceACLsAsJson.toList();
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
            // Generate ID before calling pre-hook
            client.id ??= _generateId(policyCache.clients);
            if(policyOperationHooks?.prePutClient != null) {
              try {
                await policyOperationHooks!.prePutClient!(client);
              } catch(e, s) {
                logger.severe('prePutClient hook failed for client ${client.atSign}', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putClient(client);
            if(!success) {
              message = 'Failed to store client with atSign: ${client.atSign}';
              break;
            }
            // Call post-hook if provided (errors are logged but don't fail the operation)
            if(policyOperationHooks?.postPutClient != null) {
              try {
                await policyOperationHooks!.postPutClient!(client);
              } catch(e, s) {
                logger.severe('postPutClient hook failed for client ${client.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientId'] = client.id!; // client.id is non-null after ID generation
            message = 'Client stored successfully.';
            break;
          }
          case 'ClientGroup': {
            final ClientGroup clientGroup = ClientGroup.fromJson(valueAsMap);
            // Generate ID before calling pre-hook
            clientGroup.id ??= _generateId(policyCache.clientGroups);
            // Call pre-hook if provided
            if(policyOperationHooks?.prePutClientGroup != null) {
              try {
                await policyOperationHooks!.prePutClientGroup!(clientGroup);
              } catch(e, s) {
                logger.severe('prePutClientGroup hook failed for client group ${clientGroup.name}', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putClientGroup(clientGroup);
            if(!success) {
              message = 'Failed to store client group with name: ${clientGroup.name}';
              break;
            }
            // Call post-hook if provided
            if(policyOperationHooks?.postPutClientGroup != null) {
              try {
                await policyOperationHooks!.postPutClientGroup!(clientGroup);
              } catch(e, s) {
                logger.severe('postPutClientGroup hook failed for client group ${clientGroup.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientGroupId'] = clientGroup.id!; // clientGroup.id is non-null after ID generation
            message = 'Client group stored successfully.';
            break;
          }
          case 'ClientGroupMember': {
            final ClientGroupMember clientGroupMember = ClientGroupMember.fromJson(valueAsMap);
            // Generate ID before calling pre-hook
            clientGroupMember.id ??= _generateId(policyCache.clientGroupMembers);
            // Call pre-hook if provided
            if(policyOperationHooks?.prePutClientGroupMember != null) {
              try {
                await policyOperationHooks!.prePutClientGroupMember!(clientGroupMember);
              } catch(e, s) {
                logger.severe('prePutClientGroupMember hook failed', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putClientGroupMember(clientGroupMember);
            if(!success) {
              message = 'Failed to store client group member: '
                'clientId=${clientGroupMember.clientId} '
                'clientGroupId=${clientGroupMember.clientGroupId}';
              break;
            }
            // Call post-hook if provided
            if(policyOperationHooks?.postPutClientGroupMember != null) {
              try {
                await policyOperationHooks!.postPutClientGroupMember!(clientGroupMember);
              } catch(e, s) {
                logger.severe('postPutClientGroupMember hook failed for client group member ${clientGroupMember.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientGroupMemberId'] = clientGroupMember.id!; // clientGroupMember.id is non-null after ID generation
            message = 'Client group member stored successfully.';
            break;
          }
          case 'Daemon': {
            final Daemon daemon = Daemon.fromJson(valueAsMap);
            // Generate ID before calling pre-hook
            daemon.id ??= _generateId(policyCache.daemons);
            // Call pre-hook if provided
            if(policyOperationHooks?.prePutDaemon != null) {
              try {
                await policyOperationHooks!.prePutDaemon!(daemon);
              } catch(e, s) {
                logger.severe('prePutDaemon hook failed for daemon ${daemon.atSign}', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putDaemon(daemon);
            if(!success) {
              message = 'Failed to store daemon with atSign: ${daemon.atSign}';
              break;
            }
            // Call post-hook if provided
            if(policyOperationHooks?.postPutDaemon != null) {
              try {
                await policyOperationHooks!.postPutDaemon!(daemon);
              } catch(e, s) {
                logger.severe('postPutDaemon hook failed for daemon ${daemon.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['daemonId'] = daemon.id!; // daemon.id is non-null after ID generation
            message = 'Daemon stored successfully.';
            break;
          }
          case 'Service': {
            final Service service = Service.fromJson(valueAsMap);
            // Generate ID before calling pre-hook
            service.id ??= _generateId(policyCache.services);
            // Call pre-hook if provided
            if(policyOperationHooks?.prePutService != null) {
              try {
                await policyOperationHooks!.prePutService!(service);
              } catch(e, s) {
                logger.severe('prePutService hook failed for service', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putService(service);
            if(!success) {
              message = 'Failed to store service: '
                'deviceName=${service.deviceName} '
                'daemonId=${service.daemonId}';
              break;
            }
            // Call post-hook if provided
            if(policyOperationHooks?.postPutService != null) {
              try {
                await policyOperationHooks!.postPutService!(service);
              } catch(e, s) {
                logger.severe('postPutService hook failed for service ${service.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['serviceId'] = service.id!; // service.id is non-null after ID generation
            message = 'Service stored successfully.';
            break;
          }
          case 'ServiceACL': {
            final ServiceACL serviceACL = ServiceACL.fromJson(valueAsMap);
            // Generate ID before calling pre-hook
            serviceACL.id ??= _generateId(policyCache.serviceACLs);
            // Call pre-hook if provided
            if(policyOperationHooks?.prePutServiceACL != null) {
              try {
                await policyOperationHooks!.prePutServiceACL!(serviceACL);
              } catch(e, s) {
                logger.severe('prePutServiceACL hook failed for service ACL', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = policyCache.putServiceACL(serviceACL);
            if(!success) {
              message = 'Failed to store service ACL: '
                'serviceId=${serviceACL.serviceId} '
                'clientGroupId=${serviceACL.clientGroupId} '
                'permitOpen=${serviceACL.permitOpen}';
              break;
            }
            // Call post-hook if provided
            if(policyOperationHooks?.postPutServiceACL != null) {
              try {
                await policyOperationHooks!.postPutServiceACL!(serviceACL);
              } catch(e, s) {
                logger.severe('postPutServiceACL hook failed for service ACL ${serviceACL.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['serviceACLId'] = serviceACL.id!; // serviceACL.id is non-null after ID generation
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
    return AtRpcResp(
      reqId: reqId,
      payload: responsePayload,
      message: message,
      respType: success ? AtRpcRespType.success : AtRpcRespType.error);
  }

  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError(); 
  }

}

