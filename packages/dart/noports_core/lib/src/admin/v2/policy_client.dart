import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/admin_v2.dart';

class PolicyClient {
  late AtRpcClient _atRpcClient;

  PolicyClient({
    required final AtClient atClient,
    required final String serverAtSign}) {
    _atRpcClient = AtRpcClient(
      serverAtsign: serverAtSign,
      atClient: atClient,
      baseNameSpace: 'sshnp',
      domainNameSpace: 'policy');
  }


  Future<dynamic> executePolicyDataOperation(final PolicyDataOperation policyDataOperation) async {
    final Map<String, dynamic> response = await _atRpcClient.call(policyDataOperation.atRpcPayload);
    return response;

  }

  Future<Set<Client>> getClients() async {
    final Set<Client> clients = {};

    // final PolicyDataOperation operation = PolicyDataOperation.getAllClients();
    // final Map<String, dynamic> response = await executePolicyDataOperation(operation);
    // final List<dynamic> clientsAsJson = response['value'];
    // final String client0AsStr = clientsAsJson[0];
    // Map<String, dynamic> client0AsJson = jsonDecode(client0AsStr);

    return clients;
  }

  // ... other methods to get ClientGroups, Daemons, Services, etc.
  
}

