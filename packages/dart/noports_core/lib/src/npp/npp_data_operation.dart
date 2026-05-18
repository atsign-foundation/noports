import 'package:noports_core/npp.dart';

class NppDataOperation {
  final Map<String, dynamic> atRpcPayload;

  NppDataOperation({required this.atRpcPayload});

  factory NppDataOperation.ping() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'ping',
      },
    );
  }

  factory NppDataOperation.simulate({
    required String daemonAtsign,
    required String deviceName,
    required String deviceGroupName,
    required String clientAtsign,
  }) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'simulate',
        'daemonAtsign': daemonAtsign,
        'daemonDeviceName': deviceName,
        'daemonDeviceGroupName': deviceGroupName,
        'clientAtsign': clientAtsign,
      },
    );
  }

  factory NppDataOperation.getAllClients() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClients',
      },
    );
  }

  factory NppDataOperation.getAllClientGroups() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroups',
      },
    );
  }

  factory NppDataOperation.getAllClientGroupMembers() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allClientGroupMembers',
      },
    );
  }

  factory NppDataOperation.getAllDaemons() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allDaemons',
      },
    );
  }

  factory NppDataOperation.getAllServices() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServices',
      },
    );
  }

  factory NppDataOperation.getAllServiceACLs() {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'get',
        'target': 'allServiceACLs',
      },
    );
  }

  factory NppDataOperation.putClient(final Client client) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Client',
        'value': client.toJson(),
      },
    );
  }

  factory NppDataOperation.putClientGroup(final ClientGroup clientGroup) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroup',
        'value': clientGroup.toJson(),
      },
    );
  }

  factory NppDataOperation.putClientGroupMember(final ClientGroupMember clientGroupMember) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ClientGroupMember',
        'value': clientGroupMember.toJson(),
      },
    );
  }

  factory NppDataOperation.putDaemon(final Daemon daemon) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Daemon',
        'value': daemon.toJson(),
      },
    );
  }

  factory NppDataOperation.putService(final Service service) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'Service',
        'value': service.toJson(),
      },
    );
  }

  factory NppDataOperation.putServiceACL(final ServiceACL serviceACL) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'put',
        'target': 'ServiceACL',
        'value': serviceACL.toJson(),
      }
    );
  }

  factory NppDataOperation.deleteClient(final String clientId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Client',
        'value': {'clientId': clientId},
      }
    );
  }

  factory NppDataOperation.deleteClientGroup(final String clientGroupId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ClientGroup',
        'value': {'clientGroupId': clientGroupId},
      }
    );
  }

  factory NppDataOperation.deleteClientGroupMember(final String clientGroupMemberId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ClientGroupMember',
        'value': {'clientGroupMemberId': clientGroupMemberId},
      }
    );
  }

  factory NppDataOperation.deleteDaemon(final String daemonId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Daemon',
        'value': {'daemonId': daemonId},
      }
    );
  }

  factory NppDataOperation.deleteService(final String serviceId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'Service',
        'value': {'serviceId': serviceId},
      }
    );
  }

  factory NppDataOperation.deleteServiceACL(final String serviceACLId) {
    return NppDataOperation(
      atRpcPayload: {
        'operation': 'delete',
        'target': 'ServiceACL',
        'value': {'serviceACLId': serviceACLId},
      }
    );
  }
}
