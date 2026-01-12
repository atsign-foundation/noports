import 'dart:convert';

import 'package:noports_core/admin_v2.dart';

class PolicyDataOperation {
  final String operation; // e.g. "get", "put",
  final Map<String, dynamic> atRpcPayload;

  PolicyDataOperation({
    required this.operation,
    required this.atRpcPayload});


  factory PolicyDataOperation.getAllClients() {
    return PolicyDataOperation(
      operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClients',
        'value': {},
      },
    );
  }

  factory PolicyDataOperation.getAllClientGroups() {
    return PolicyDataOperation(
      operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroups',
        'value': {},
      },
    );
  } 

  factory PolicyDataOperation.getAllClientGroupMembers() {
    return PolicyDataOperation(
      operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroupMembers',
        'value': {},
      },
    );
  } 

  factory PolicyDataOperation.getAllDaemons() {
    return PolicyDataOperation(
        operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allDaemons',
        'value': {},
      },
    );
  } 

  factory PolicyDataOperation.getAllServices() {
    return PolicyDataOperation(
      operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServices',
        'value': {},
      },
    );
  } 

  factory PolicyDataOperation.getAllServiceACLs() {
    return PolicyDataOperation(
      operation: 'get',
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServiceACLs',
        'value': {},
      },
    );
  } 

  factory PolicyDataOperation.putClient(final Client client) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'Client',
        'value': client.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putClientGroup(final ClientGroup clientGroup) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroup',
        'value': jsonEncode(clientGroup.toJson()),
      },
    );
  }

  factory PolicyDataOperation.putClientGroupMember(final ClientGroupMember clientGroupMember) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroupMember',
        'value': jsonEncode(clientGroupMember.toJson()),
      },
    );
  }

  factory PolicyDataOperation.putDaemon(final Daemon daemon) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'Daemon',
        'value': jsonEncode(daemon.toJson()),
      },
    );
  }

  factory PolicyDataOperation.putService(final Service service) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'Service',
        'value': jsonEncode(service.toJson()),
      },
    );
  }

  factory PolicyDataOperation.putServiceACL(final ServiceACL serviceACL) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ServiceACL',
        'value': jsonEncode(serviceACL.toJson()),
      }
    );
  }
}

