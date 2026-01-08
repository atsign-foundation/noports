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
    print(jsonEncode(response));
    return response;
  }

  Future<Set<Client>> getAllClients() async {
    final Set<Client> clients = {};

    final PolicyDataOperation operation = PolicyDataOperation.getAllClients();
    final Map<String, dynamic> response = await executePolicyDataOperation(operation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response: $response');
    }
    if(!response.containsKey('message')) {
      throw Exception('message key not found in response map: $response');
    }
    if(!response.containsKey('value')) {
      throw Exception('value key not found in response map: $response');
    }
    final bool success = response['success'];
    final String message = response['message'];
    final dynamic valueString = response['value'];
    return clients;
  }

  // ... other methods to get ClientGroups, Daemons, Services, etc.
  
}

