import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/src/version.dart' as core_version;

/// Callbacks for handling policy manager RPC requests
class ManagerRpcCallbacks implements AtRpcCallbacks {
  final AtClient atClient;
  final NppCache nppCache;
  final NppOperationHooks? nppOperationHooks;
  final String binariesVersion;
  final NPARequestHandler handler;
  final AtSignLogger logger = AtSignLogger('ManagerRpcCallbacks');

  ManagerRpcCallbacks({
    required this.atClient,
    required this.nppCache,
    required this.binariesVersion,
    required this.handler,
    this.nppOperationHooks,
  });

  String _generateId(Set<PolicyEntry> entities) {
    int maxId = 0;
    for (final PolicyEntry entry in entities) {
      if (entry.id == null) {
        continue;
      }
      final int entryId = int.tryParse(entry.id!) ?? 0;
      if (entryId > maxId) {
        maxId = entryId;
      }
    }
    return (maxId + 1).toString();
  }

  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    final int reqId = request.reqId;
    if (fromAtSign != atClient.getCurrentAtSign()) {
      return AtRpcResp(
          reqId: reqId,
          respType: AtRpcRespType.error,
          message: 'Unauthorized atSign',
          payload: {'success': false});
    }
    final Map<String, dynamic> requestPayload = request.payload;
    final Map<String, dynamic> responsePayload = {};
    if (!requestPayload.containsKey('operation')) {
      return AtRpcResp(
        reqId: reqId,
        respType: AtRpcRespType.error,
        message: 'operation JSON key was not found in the payload.',
        payload: {},
      );
    }
    final String operation = requestPayload['operation'];
    final String? target = requestPayload['target'];
    late String message;
    late bool success;
    switch (operation) {
      case 'ping': {
        logger.info('Received ping request from $fromAtSign');
        responsePayload['status'] = 'alive';
        responsePayload['coreVersion'] = core_version.packageVersion;
        responsePayload['binariesVersion'] = binariesVersion;
        responsePayload['timestamp'] = DateTime.now().toIso8601String();
        success = true;
        message = 'pong';
        break;
      }
      case 'simulate': {
        logger.info('Received simulate request from $fromAtSign');
        try {
          final NPAAuthCheckRequest authCheckRequest = 
            NPAAuthCheckRequest.fromJson(requestPayload);
          final NPAAuthCheckResponse authCheckResponse = 
            await handler.doAuthCheck(authCheckRequest);
         responsePayload.addAll(authCheckResponse.toJson());
          success = true;
          message = 'Auth check completed.';
        } catch (e) {
          success = false;
          message = 'Failed to check auth: $e';
        }
        break;
      }
      case 'get': {
        if(target == null) {
          success = false;
          message = 'target JSON key was not found in the payload.';
          break;
        }
        switch (target) {
          case 'allClients': {
            final Set<Client> clients = nppCache.clients;
            final Set<Map<String, dynamic>> clientsAsJson =
                clients.map((client) => client.toJson()).toSet();
            final int amount = clientsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientsAsJson.toList();
            message = '$amount Clients found.';
            success = true;
            break;
          }
          case 'allClientGroups': {
            final Set<ClientGroup> clientGroups = nppCache.clientGroups;
            final Set<Map<String, dynamic>> clientGroupsAsJson = clientGroups
                .map((clientGroup) => clientGroup.toJson())
                .toSet();
            final int amount = clientGroupsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupsAsJson.toList();
            message = '$amount ClientGroups found.';
            success = true;
            break;
          }
          case 'allClientGroupMembers': {
            final Set<ClientGroupMember> clientGroupMembers =
                nppCache.clientGroupMembers;
            final Set<Map<String, dynamic>> clientGroupMembersAsJson =
                clientGroupMembers
                    .map((clientGroupMember) => clientGroupMember.toJson())
                    .toSet();
            final int amount = clientGroupMembersAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = clientGroupMembersAsJson.toList();
            message = '$amount ClientGroupMembers found.';
            success = true;
            break;
          }
          case 'allDaemons': {
            final Set<Daemon> daemons = nppCache.daemons;
            final Set<Map<String, dynamic>> daemonsAsJson =
                daemons.map((daemon) => daemon.toJson()).toSet();
            final int amount = daemonsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = daemonsAsJson.toList();
            message = '$amount daemons found.';
            success = true;
            break;
          }
          case 'allServices': {
            final Set<Service> services = nppCache.services;
            final Set<Map<String, dynamic>> servicesAsJson =
                services.map((service) => service.toJson()).toSet();
            final int amount = servicesAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = servicesAsJson.toList();
            message = '$amount services found.';
            success = true;
            break;
          }
          case 'allServiceACLs': {
            final Set<ServiceACL> serviceACLs = nppCache.serviceACLs;
            final Set<Map<String, dynamic>> serviceACLsAsJson =
                serviceACLs.map((serviceACL) => serviceACL.toJson()).toSet();
            final int amount = serviceACLsAsJson.length;
            responsePayload['amount'] = amount;
            responsePayload['list'] = serviceACLsAsJson.toList();
            message = '$amount ServiceACLs found.';
            success = true;
            break;
          }
          default: {
            success = false;
            message = 'Unknown target for get operation: $target';
            break;
          }
        }
        break;
      }
      case 'put': {
        if(target == null || !requestPayload.containsKey('value')) {
          success = false;
          message = 'target or value JSON keys was not found in the payload.';
          break;
        }
        final Map<String, dynamic> valueAsMap = requestPayload['value'];
        switch (target) {
          case 'Client': {
            final Client client = Client.fromJson(valueAsMap);
            client.id ??= _generateId(nppCache.clients);
            if (nppOperationHooks?.prePutClient != null) {
              try {
                await nppOperationHooks!.prePutClient!(client);
              } catch (e, s) {
                logger.severe(
                    'prePutClient hook failed for client ${client.atSign}',
                    e,
                    s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putClient(client);
            if (!success) {
              message = 'Failed to store client with atSign: ${client.atSign}';
              break;
            }
            if (nppOperationHooks?.postPutClient != null) {
              try {
                await nppOperationHooks!.postPutClient!(client);
              } catch (e, s) {
                logger.severe(
                    'postPutClient hook failed for client ${client.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientId'] =
                client.id!; // client.id is non-null after ID generation
            message = 'Client stored successfully.';
            break;
          }
          case 'ClientGroup': {
            final ClientGroup clientGroup = ClientGroup.fromJson(valueAsMap);
            clientGroup.id ??= _generateId(nppCache.clientGroups);
            if (nppOperationHooks?.prePutClientGroup != null) {
              try {
                await nppOperationHooks!.prePutClientGroup!(clientGroup);
              } catch (e, s) {
                logger.severe(
                    'prePutClientGroup hook failed for client group ${clientGroup.name}',
                    e,
                    s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putClientGroup(clientGroup);
            if (!success) {
              message =
                  'Failed to store client group with name: ${clientGroup.name}';
              break;
            }
            if (nppOperationHooks?.postPutClientGroup != null) {
              try {
                await nppOperationHooks!.postPutClientGroup!(clientGroup);
              } catch (e, s) {
                logger.severe(
                    'postPutClientGroup hook failed for client group ${clientGroup.id}',
                    e,
                    s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientGroupId'] =
                clientGroup.id!; // clientGroup.id is non-null after ID generation
            message = 'Client group stored successfully.';
            break;
          }
          case 'ClientGroupMember': {
            final ClientGroupMember clientGroupMember =
                ClientGroupMember.fromJson(valueAsMap);
            clientGroupMember.id ??=
                _generateId(nppCache.clientGroupMembers);
            if (nppOperationHooks?.prePutClientGroupMember != null) {
              try {
                await nppOperationHooks!
                    .prePutClientGroupMember!(clientGroupMember);
              } catch (e, s) {
                logger.severe(
                    'prePutClientGroupMember hook failed', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putClientGroupMember(clientGroupMember);
            if (!success) {
              message = 'Failed to store client group member: '
                  'clientId=${clientGroupMember.clientId} '
                  'clientGroupId=${clientGroupMember.clientGroupId}';
              break;
            }
            if (nppOperationHooks?.postPutClientGroupMember != null) {
              try {
                await nppOperationHooks!
                    .postPutClientGroupMember!(clientGroupMember);
              } catch (e, s) {
                logger.severe(
                    'postPutClientGroupMember hook failed for client group member ${clientGroupMember.id}',
                    e,
                    s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['clientGroupMemberId'] =
                clientGroupMember.id!; // clientGroupMember.id is non-null after ID generation
            message = 'Client group member stored successfully.';
            break;
          }
          case 'Daemon': {
            final Daemon daemon = Daemon.fromJson(valueAsMap);
            daemon.id ??= _generateId(nppCache.daemons);
            if (nppOperationHooks?.prePutDaemon != null) {
              try {
                await nppOperationHooks!.prePutDaemon!(daemon);
              } catch (e, s) {
                logger.severe(
                    'prePutDaemon hook failed for daemon ${daemon.atSign}',
                    e,
                    s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putDaemon(daemon);
            if (!success) {
              message = 'Failed to store daemon with atSign: ${daemon.atSign}';
              break;
            }
            if (nppOperationHooks?.postPutDaemon != null) {
              try {
                await nppOperationHooks!.postPutDaemon!(daemon);
              } catch (e, s) {
                logger.severe(
                    'postPutDaemon hook failed for daemon ${daemon.id}', e, s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['daemonId'] =
                daemon.id!; // daemon.id is non-null after ID generation
            message = 'Daemon stored successfully.';
            break;
          }
          case 'Service': {
            final Service service = Service.fromJson(valueAsMap);
            service.id ??= _generateId(nppCache.services);
            if (nppOperationHooks?.prePutService != null) {
              try {
                await nppOperationHooks!.prePutService!(service);
              } catch (e, s) {
                logger.severe('prePutService hook failed for service', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putService(service);
            if (!success) {
              message = 'Failed to store service: '
                  'deviceName=${service.deviceName} '
                  'daemonId=${service.daemonId}';
              break;
            }
            if (nppOperationHooks?.postPutService != null) {
              try {
                await nppOperationHooks!.postPutService!(service);
              } catch (e, s) {
                logger.severe(
                    'postPutService hook failed for service ${service.id}',
                    e,
                    s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['serviceId'] =
                service.id!; // service.id is non-null after ID generation
            message = 'Service stored successfully.';
            break;
          }
          case 'ServiceACL': {
            final ServiceACL serviceACL = ServiceACL.fromJson(valueAsMap);
            serviceACL.id ??= _generateId(nppCache.serviceACLs);
            if (nppOperationHooks?.prePutServiceACL != null) {
              try {
                await nppOperationHooks!.prePutServiceACL!(serviceACL);
              } catch (e, s) {
                logger.severe(
                    'prePutServiceACL hook failed for service ACL', e, s);
                success = false;
                message = 'Pre-operation hook failed: $e';
                break;
              }
            }
            success = nppCache.putServiceACL(serviceACL);
            if (!success) {
              message = 'Failed to store service ACL: '
                  'serviceId=${serviceACL.serviceId} '
                  'clientGroupId=${serviceACL.clientGroupId} '
                  'permitOpen=${serviceACL.permitOpen}';
              break;
            }
            if (nppOperationHooks?.postPutServiceACL != null) {
              try {
                await nppOperationHooks!.postPutServiceACL!(serviceACL);
              } catch (e, s) {
                logger.severe(
                    'postPutServiceACL hook failed for service ACL ${serviceACL.id}',
                    e,
                    s);
              }
            }
            responsePayload['success'] = success;
            responsePayload['serviceACLId'] =
                serviceACL.id!; // serviceACL.id is non-null after ID generation
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
      }
      case 'delete': {
        if(target == null || !requestPayload.containsKey('value')) {
          success = false;
          message = 'target or value JSON keys was not found in the payload.';
          break;
        }
        final Map<String, dynamic> valueAsMap = requestPayload['value'];
        switch(target) {
          case 'Client': {
            final String clientId = valueAsMap['clientId'];
            success = nppCache.deleteClient(clientId);
            responsePayload['success'] = success;
            if (success) {
              message = 'Client with id $clientId deleted successfully.';
            } else {
              message = 'Failed to delete client with id $clientId.';
            }
            break;
          }
          case 'ClientGroup': {
            final String clientGroupId = valueAsMap['clientGroupId'];
            success = nppCache.deleteClientGroup(clientGroupId);
            responsePayload['success'] = success;
            if (success) {
              message = 'ClientGroup with id $clientGroupId deleted successfully.';
            } else {
              message = 'Failed to delete ClientGroup with id $clientGroupId.';
            }
            break;
          }
          case 'ClientGroupMember': {
            final String clientGroupMemberId = valueAsMap['clientGroupMemberId'];
            success = nppCache.deleteClientGroupMember(clientGroupMemberId);
            responsePayload['success'] = success;
            if (success) {
              message = 'ClientGroupMember with id $clientGroupMemberId deleted successfully.';
            } else {
              message = 'Failed to delete ClientGroupMember with id $clientGroupMemberId.';
            }
            break;
          }
          case 'Daemon': {
            final String daemonId = valueAsMap['daemonId'];
            success = nppCache.deleteDaemon(daemonId);
            responsePayload['success'] = success;
            if (success) {
              message = 'Daemon with id $daemonId deleted successfully.';
            } else {
              message = 'Failed to delete Daemon with id $daemonId.';
            }
            break;
          }
          case 'Service': {
            final String serviceId = valueAsMap['serviceId'];
            success = nppCache.deleteService(serviceId);
            responsePayload['success'] = success;
            if (success) {
              message = 'Service with id $serviceId deleted successfully.';
            } else {
              message = 'Failed to delete Service with id $serviceId.';
            }
            break;
          }
          case 'ServiceACL': {
            final String serviceACLId = valueAsMap['serviceACLId'];
            success = nppCache.deleteServiceACL(serviceACLId);
            responsePayload['success'] = success;
            if (success) {
              message = 'ServiceACL with id $serviceACLId deleted successfully.';
            } else {
              message = 'Failed to delete ServiceACL with id $serviceACLId.';
            }
            break;
          }
          default: {
            success = false;
            message = 'Unknown target for delete operation: $target';
            break;
          }
        }
      }
      default: {
        success = false;
        message = 'Unknown operation: $operation';
        break;
      }
    }
    return AtRpcResp(
      reqId: reqId,
      payload: responsePayload,
      message: message,
      respType: success ? AtRpcRespType.success : AtRpcRespType.error,
    );
  }

  @override
  Future<void> handleResponse(AtRpcResp response) {
    throw UnimplementedError('ManagerRpcCallbacks only receives requests, does not send them');
  }
}
