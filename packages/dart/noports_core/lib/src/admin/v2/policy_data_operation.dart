import 'package:policyv3/models.dart';

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
        'value': client.toJson().toString(),
      },
    );
  }

  factory PolicyDataOperation.putClientGroup(final ClientGroup clientGroup) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroup',
        'value': clientGroup.toJson().toString(),
      },
    );
  }

  factory PolicyDataOperation.putClientGroupMember(final ClientGroupMember clientGroupMember) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroupMember',
        'value': clientGroupMember.toJson().toString(),
      },
    );
  }

  factory PolicyDataOperation.putDaemon(final Daemon daemon) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'Daemon',
        'value': daemon.toJson().toString(),
      },
    );
  }

  factory PolicyDataOperation.putService(final Service service) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'Service',
        'value': service.toJson().toString(),
      },
    );
  }

  factory PolicyDataOperation.putServiceACL(final ServiceACL serviceACL) {
    return PolicyDataOperation(
      operation: 'put',
      atRpcPayload: {
        'operation': 'put',
        'target': 'ServiceACL',
        'value': serviceACL.toJson().toString(),
      }
    );
  }
}

