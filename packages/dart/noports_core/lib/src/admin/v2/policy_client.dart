import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/admin_v2.dart';

class PolicyClient {
  late AtRpcClient _atRpcClient;

  PolicyClient._();

  factory PolicyClient.fromAtRpcClient({
    required final AtRpcClient atRpcClient}) {
    PolicyClient policyClient = PolicyClient._();
    policyClient._atRpcClient = atRpcClient;
    return policyClient;
  }

  PolicyClient({
    required final AtClient atClient,
    required final String serverAtSign,
    required final String baseNameSpace,
    required final String domainNameSpace,
  }) {
    _atRpcClient = AtRpcClient(
      serverAtsign: serverAtSign,
      atClient: atClient,
      baseNameSpace: baseNameSpace,
      domainNameSpace: domainNameSpace
    );
  }


  Future<dynamic> executePolicyDataOperation(final PolicyDataOperation policyDataOperation) async {
    final Map<String, dynamic> response = await _atRpcClient.call(policyDataOperation.atRpcPayload);
    return response;
  }

  Future<Set<Client>> getAllClients() async {
    final PolicyDataOperation operation = PolicyDataOperation.getAllClients();
    final Map<String, dynamic> response = await executePolicyDataOperation(operation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<Client> clients = list.map((object) => Client.fromJson(object)).toSet();
    if(amount != clients.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of clients: expected=$amount actual=${clients.length}');
    }
    return clients;
  }

  Future<Set<ClientGroup>> getAllClientGroups() async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.getAllClientGroups();
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<ClientGroup> clientGroups = list.map((object) => ClientGroup.fromJson(object)).toSet();
    if(amount != clientGroups.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of clientGroups: expected=$amount actual=${clientGroups.length}');
    }
    return clientGroups;
  }

  Future<Set<ClientGroupMember>> getAllClientGroupMembers() async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.getAllClientGroupMembers();
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<ClientGroupMember> clientGroupMembers = list.map((object) => ClientGroupMember.fromJson(object)).toSet();
    if(amount != clientGroupMembers.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of clientGroupMembers: expected=$amount actual=${clientGroupMembers.length}');
    }
    return clientGroupMembers;
  }

  Future<Set<Daemon>> getAllDaemons() async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.getAllDaemons();
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<Daemon> daemons = list.map((object) => Daemon.fromJson(object)).toSet();
    if(amount != daemons.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of daemons: expected=$amount actual=${daemons.length}');
    }
    return daemons;
  }

  Future<Set<Service>> getAllServices() async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.getAllServices();
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<Service> services = list.map((object) => Service.fromJson(object)).toSet();
    if(amount != services.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of services: expected=$amount actual=${services.length}');
    }
    return services;
  }

  Future<Set<ServiceACL>> getAllServiceACLs() async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.getAllServiceACLs();
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('amount')) {
      throw Exception('amount key not found in response map: $response');
    }
    if(!response.containsKey('list')) {
      throw Exception('list key not found in response map: $response');
    }
    final int amount = response['amount'];
    final List<dynamic> list = response['list'];
    final Set<ServiceACL> serviceACLs = list.map((object) => ServiceACL.fromJson(object)).toSet();
    if(amount != serviceACLs.length) {
      logger.warning('Something weird happened... we did not parse the correct amount of serviceACLs: expected=$amount actual=${serviceACLs.length}');
    }
    return serviceACLs;
  }

  Future<bool> putClient(final Client client) async {
    final PolicyDataOperation policyDataOperation = PolicyDataOperation.putClient(client);
    final Map<String, dynamic> response = await executePolicyDataOperation(policyDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    final bool success = response['success'];
    return success;
  }
  
}

