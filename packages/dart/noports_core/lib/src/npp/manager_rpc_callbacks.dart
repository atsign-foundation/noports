import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';
import 'package:mutex/mutex.dart';
import 'package:noports_core/src/events/noports_event_types.dart';
import 'package:noports_core/src/version.dart' as core_version;

/// Receives each rule a delete removes with the one it names.
typedef _LogRemoved = Future<void> Function(
    String target, Map<String, dynamic> rule);

/// Callbacks for handling policy manager RPC requests
class ManagerRpcCallbacks implements AtRpcCallbacks {
  final AtClient atClient;
  final NppCache nppCache;
  final NppOperationHooks? nppOperationHooks;
  final String binariesVersion;
  final NPARequestHandler handler;
  final Atsign policyAtsign;

  /// Receives each policy event.
  final Future<void> Function(Map<String, dynamic> event) onEvent;
  final AtSignLogger logger = AtSignLogger('ManagerRpcCallbacks');

  /// Lets one put or delete run at a time, from checking it to sending its
  /// events, so a put can't name a rule a delete is removing and events
  /// follow the changes in order. Reads aren't held by it.
  final Mutex _changes = Mutex();

  /// Set by [stopChanges]: once true, puts and deletes are refused.
  bool _stopping = false;

  ManagerRpcCallbacks({
    required this.atClient,
    required this.nppCache,
    required this.binariesVersion,
    required this.handler,
    required this.policyAtsign,
    required this.onEvent,
    this.nppOperationHooks,
  });

  /// Why a put of [entry] is refused for naming a rule the cache doesn't
  /// hold, or null when every rule it names is there.
  String? _namesMissingRule(PolicyEntry entry) {
    final List<String> missing = nppCache.missingReferences(entry);
    if (missing.isEmpty) {
      return null;
    }
    return 'No ${missing.join(' or ')}, so nothing is put.';
  }

  /// Runs [preDelete] on [entry], a [target] rule, and returns why it failed,
  /// or null when it succeeds or there is no hook.
  Future<String?> _preDelete<T extends PolicyEntry>(
    Future<void> Function(T)? preDelete,
    T entry,
    String target,
  ) async {
    if (preDelete == null) {
      return null;
    }
    try {
      await preDelete(entry);
      return null;
    } catch (e, s) {
      logger.severe('preDelete hook failed for $target ${entry.id}', e, s);
      return 'Pre-operation hook failed: $e';
    }
  }

  /// Deletes [entry], a [target] rule, after the [members] and [serviceACLs]
  /// that name it. Each is deleted by its pre-delete hook, then from the
  /// cache, then added to [removed] and passed to [logRemoved]; [entry] goes
  /// last, through [removeEntry]. Returns why a hook failed, leaving that rule
  /// and those after it in place, so no rule left names one that is gone.
  Future<String?> _deleteWithLinks<T extends PolicyEntry>({
    required String target,
    required T entry,
    required Future<void> Function(T)? preDelete,
    required void Function() removeEntry,
    Iterable<ClientGroupMember> members = const [],
    Iterable<ServiceACL> serviceACLs = const [],
    required List<Map<String, dynamic>> removed,
    required _LogRemoved logRemoved,
  }) async {
    for (final ClientGroupMember member in members.toList()) {
      final String? error = await _preDelete(
          nppOperationHooks?.preDeleteClientGroupMember,
          member,
          'ClientGroupMember');
      if (error != null) {
        return error;
      }
      nppCache.deleteClientGroupMember(member.id!);
      removed.add({'target': 'ClientGroupMember', 'id': member.id});
      await logRemoved('ClientGroupMember', member.toJson());
    }
    for (final ServiceACL serviceACL in serviceACLs.toList()) {
      final String? error = await _preDelete(
          nppOperationHooks?.preDeleteServiceACL, serviceACL, 'ServiceACL');
      if (error != null) {
        return error;
      }
      nppCache.deleteServiceACL(serviceACL.id!);
      removed.add({'target': 'ServiceACL', 'id': serviceACL.id});
      await logRemoved('ServiceACL', serviceACL.toJson());
    }
    final String? error = await _preDelete(preDelete, entry, target);
    if (error != null) {
      return error;
    }
    removeEntry();
    return null;
  }

  /// Builds an event with [build] and hands it to [onEvent]. A failure in
  /// either is logged and swallowed: the event log must never change the
  /// answer a manager gets.
  Future<void> _sendEvent(Map<String, dynamic> Function() build) async {
    try {
      await onEvent(build());
    } catch (e) {
      logger.warning('Failed to log policy event: $e');
    }
  }

  /// Answers [request], telling the event logging Atsign about each sender
  /// refused and each attempt to put or delete a rule. `fromAtsign` in those
  /// events is [fromAtSign], which AtRpc takes from the notification, never
  /// from the payload. Reads change nothing, so they aren't logged.
  @override
  Future<AtRpcResp> handleRequest(AtRpcReq request, String fromAtSign) async {
    final int reqId = request.reqId;
    if (fromAtSign != atClient.getCurrentAtSign()) {
      await _sendEvent(() => PolicyEvent.managerRequestRefused(
        policyAtsign: policyAtsign,
        fromAtsign: fromAtSign.toAtsign(),
        reqId: reqId,
      ));
      return AtRpcResp(
          reqId: reqId,
          respType: AtRpcRespType.error,
          message: 'Unauthorized atSign',
          payload: {'success': false});
    }
    final Object? operation = request.payload['operation'];
    final Map<String, dynamic> rule = {};
    if (operation != 'put' && operation != 'delete') {
      return _handleRequest(request, fromAtSign, rule, (_, __) async {});
    }

    Future<void> logRemoved(String target, Map<String, dynamic> removed) =>
        _sendEvent(() => PolicyEvent.ruleChanged(
          policyAtsign: policyAtsign,
          fromAtsign: fromAtSign.toAtsign(),
          reqId: reqId,
          operation: 'delete',
          target: target,
          rule: removed,
        ));

    Future<void> logChange(String? error) => _sendEvent(() {
      final String? target = request.payload['target']?.toString();
      if (error == null) {
        return PolicyEvent.ruleChanged(
          policyAtsign: policyAtsign,
          fromAtsign: fromAtSign.toAtsign(),
          reqId: reqId,
          operation: operation as String,
          target: target,
          rule: rule,
        );
      }
      return PolicyEvent.ruleChangeFailed(
        policyAtsign: policyAtsign,
        fromAtsign: fromAtSign.toAtsign(),
        reqId: reqId,
        operation: operation as String,
        target: target,
        rule: rule,
        error: error,
      );
    });

    return _changes.protect(() async {
      if (_stopping) {
        await logChange('npp is stopping');
        return AtRpcResp(
            reqId: reqId,
            respType: AtRpcRespType.error,
            message: 'npp is stopping',
            payload: {'success': false});
      }
      final AtRpcResp response;
      try {
        response = await _handleRequest(request, fromAtSign, rule, logRemoved);
      } catch (e) {
        await logChange('$e');
        rethrow;
      }
      await logChange(
          response.respType == AtRpcRespType.error
              ? response.message ?? 'no message'
              : null);
      return response;
    });
  }

  /// Refuses every later put and delete, after waiting for one already
  /// running to finish and send its event. Called when npp starts stopping,
  /// so no rule changes once the event log can no longer record it.
  Future<void> stopChanges() => _changes.protect(() async {
    _stopping = true;
  });

  /// Carries out [request]. [rule] receives the rule a put or delete acts on;
  /// it is per request, since reads aren't held by [_changes]. A delete passes
  /// each rule it removes with the one requested to [logRemoved].
  Future<AtRpcResp> _handleRequest(
    AtRpcReq request,
    String fromAtSign,
    Map<String, dynamic> rule,
    _LogRemoved logRemoved,
  ) async {
    final int reqId = request.reqId;
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
        if (valueAsMap['id'] != null) {
          success = false;
          message = 'A put must not name an id: npp gives each new rule one.';
          break;
        }
        switch (target) {
          case 'Client': {
            final Client client = Client.fromJson(valueAsMap);
            client.id = newPolicyEntryId();
            rule.addAll(client.toJson());
            nppCache.checkPutClient(client);
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
            clientGroup.id = newPolicyEntryId();
            rule.addAll(clientGroup.toJson());
            nppCache.checkPutClientGroup(clientGroup);
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
            final String? namesMissing = _namesMissingRule(clientGroupMember);
            if (namesMissing != null) {
              rule.addAll(clientGroupMember.toJson());
              success = false;
              message = namesMissing;
              break;
            }
            clientGroupMember.id = newPolicyEntryId();
            rule.addAll(clientGroupMember.toJson());
            nppCache.checkPutClientGroupMember(clientGroupMember);
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
            daemon.id = newPolicyEntryId();
            rule.addAll(daemon.toJson());
            nppCache.checkPutDaemon(daemon);
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
            final String? namesMissing = _namesMissingRule(service);
            if (namesMissing != null) {
              rule.addAll(service.toJson());
              success = false;
              message = namesMissing;
              break;
            }
            service.id = newPolicyEntryId();
            rule.addAll(service.toJson());
            nppCache.checkPutService(service);
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
            final String? namesMissing = _namesMissingRule(serviceACL);
            if (namesMissing != null) {
              rule.addAll(serviceACL.toJson());
              success = false;
              message = namesMissing;
              break;
            }
            serviceACL.id = newPolicyEntryId();
            rule.addAll(serviceACL.toJson());
            nppCache.checkPutServiceACL(serviceACL);
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
        final List<Map<String, dynamic>> removed = [];
        responsePayload['removed'] = removed;
        String? error;
        switch(target) {
          case 'Client': {
            final String clientId = valueAsMap['clientId'];
            final Client client = nppCache.getClientById(clientId);
            rule.addAll(client.toJson());
            error = await _deleteWithLinks(
              target: 'Client',
              entry: client,
              preDelete: nppOperationHooks?.preDeleteClient,
              removeEntry: () => nppCache.deleteClient(clientId),
              members: nppCache.getClientGroupMembersByClientId(clientId),
              removed: removed,
              logRemoved: logRemoved,
            );
            message = error ?? 'Client with id $clientId deleted successfully.';
            break;
          }
          case 'ClientGroup': {
            final String clientGroupId = valueAsMap['clientGroupId'];
            final ClientGroup clientGroup = nppCache.getClientGroupById(clientGroupId);
            rule.addAll(clientGroup.toJson());
            error = await _deleteWithLinks(
              target: 'ClientGroup',
              entry: clientGroup,
              preDelete: nppOperationHooks?.preDeleteClientGroup,
              removeEntry: () => nppCache.deleteClientGroup(clientGroupId),
              members:
                  nppCache.getClientGroupMembersByClientGroupId(clientGroupId),
              serviceACLs: nppCache.getServiceACLsByClientGroupId(clientGroupId),
              removed: removed,
              logRemoved: logRemoved,
            );
            message = error ??
                'ClientGroup with id $clientGroupId deleted successfully.';
            break;
          }
          case 'ClientGroupMember': {
            final String clientGroupMemberId = valueAsMap['clientGroupMemberId'];
            final ClientGroupMember clientGroupMember =
                nppCache.getClientGroupMemberById(clientGroupMemberId);
            rule.addAll(clientGroupMember.toJson());
            error = await _deleteWithLinks(
              target: 'ClientGroupMember',
              entry: clientGroupMember,
              preDelete: nppOperationHooks?.preDeleteClientGroupMember,
              removeEntry: () =>
                  nppCache.deleteClientGroupMember(clientGroupMemberId),
              removed: removed,
              logRemoved: logRemoved,
            );
            message = error ??
                'ClientGroupMember with id $clientGroupMemberId deleted successfully.';
            break;
          }
          case 'Daemon': {
            final String daemonId = valueAsMap['daemonId'];
            final Daemon daemon = nppCache.getDaemonById(daemonId);
            rule.addAll(daemon.toJson());
            final int services = nppCache.getServicesByDaemonId(daemonId).length;
            if (services > 0) {
              error = 'Daemon with id $daemonId is named by $services '
                  '${services == 1 ? 'service' : 'services'}, so it is not '
                  'deleted. Delete ${services == 1 ? 'it' : 'them'} first.';
            } else {
              error = await _deleteWithLinks(
                target: 'Daemon',
                entry: daemon,
                preDelete: nppOperationHooks?.preDeleteDaemon,
                removeEntry: () => nppCache.deleteDaemon(daemonId),
                removed: removed,
                logRemoved: logRemoved,
              );
            }
            message = error ?? 'Daemon with id $daemonId deleted successfully.';
            break;
          }
          case 'Service': {
            final String serviceId = valueAsMap['serviceId'];
            final Service service = nppCache.getServiceById(serviceId);
            rule.addAll(service.toJson());
            error = await _deleteWithLinks(
              target: 'Service',
              entry: service,
              preDelete: nppOperationHooks?.preDeleteService,
              removeEntry: () => nppCache.deleteService(serviceId),
              serviceACLs: nppCache.getServiceACLsByServiceID(serviceId),
              removed: removed,
              logRemoved: logRemoved,
            );
            message = error ?? 'Service with id $serviceId deleted successfully.';
            break;
          }
          case 'ServiceACL': {
            final String serviceACLId = valueAsMap['serviceACLId'];
            final ServiceACL serviceACL = nppCache.getServiceACLById(serviceACLId);
            rule.addAll(serviceACL.toJson());
            error = await _deleteWithLinks(
              target: 'ServiceACL',
              entry: serviceACL,
              preDelete: nppOperationHooks?.preDeleteServiceACL,
              removeEntry: () => nppCache.deleteServiceACL(serviceACLId),
              removed: removed,
              logRemoved: logRemoved,
            );
            message = error ??
                'ServiceACL with id $serviceACLId deleted successfully.';
            break;
          }
          default: {
            error = 'Unknown target for delete operation: $target';
            message = error;
            break;
          }
        }
        success = error == null;
        responsePayload['success'] = success;
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
