import 'package:noports_core/npp.dart';

class PolicyDataOperation {
  final Map<String, dynamic> atRpcPayload;

  PolicyDataOperation({required this.atRpcPayload});

  factory PolicyDataOperation.ping() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'ping',
      },
    );
  }

  factory PolicyDataOperation.getAllClients() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClients',
      },
    );
  }

  factory PolicyDataOperation.getAllClientGroups() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroups',
      },
    );
  } 

  factory PolicyDataOperation.getAllClientGroupMembers() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroupMembers',
      },
    );
  } 

  factory PolicyDataOperation.getAllDaemons() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allDaemons',
      },
    );
  } 

  factory PolicyDataOperation.getAllServices() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServices',
      },
    );
  } 

  factory PolicyDataOperation.getAllServiceACLs() {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServiceACLs',
      },
    );
  } 

  factory PolicyDataOperation.putClient(final Client client) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Client',
        'value': client.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putClientGroup(final ClientGroup clientGroup) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroup',
        'value': clientGroup.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putClientGroupMember(final ClientGroupMember clientGroupMember) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroupMember',
        'value': clientGroupMember.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putDaemon(final Daemon daemon) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Daemon',
        'value': daemon.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putService(final Service service) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Service',
        'value': service.toJson(),
      },
    );
  }

  factory PolicyDataOperation.putServiceACL(final ServiceACL serviceACL) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ServiceACL',
        'value': serviceACL.toJson(),
      }
    );
  }

  factory PolicyDataOperation.deleteClient(final String clientId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Client',
        'value': {'clientId': clientId},
      }
    );
  }

  factory PolicyDataOperation.deleteClientGroup(final String clientGroupId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ClientGroup',
        'value': {'clientGroupId': clientGroupId},
      }
    );
  }

  factory PolicyDataOperation.deleteClientGroupMember(final String clientGroupMemberId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ClientGroupMember',
        'value': {'clientGroupMemberId': clientGroupMemberId},
      }
    );
  }

  factory PolicyDataOperation.deleteDaemon(final String daemonId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Daemon',
        'value': {'daemonId': daemonId},
      }
    );
  }

  factory PolicyDataOperation.deleteService(final String serviceId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Service',
        'value': {'serviceId': serviceId},
      }
    );
  }

  factory PolicyDataOperation.deleteServiceACL(final String serviceACLId) {
    return PolicyDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ServiceACL',
        'value': {'serviceACLId': serviceACLId},
      }
    );
  }
}

