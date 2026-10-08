import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/npa.dart';


class NppClient {

  static final AtSignLogger logger = AtSignLogger('NppClient');

  final AtClient atClient;
  final String serverAtSign;
  final String baseNameSpace;
  final String domainNameSpace;

  late AtRpcClient atRpcClient;

  NppClient({
    required this.atClient,
    required this.serverAtSign,
    required this.baseNameSpace,
    required this.domainNameSpace,
  }) {
    atRpcClient = AtRpcClient(
      serverAtsign: serverAtSign,
      atClient: atClient,
      baseNameSpace: baseNameSpace,
      domainNameSpace: domainNameSpace
    );
  }


  Future<dynamic> executeNppDataOperation(final NppDataOperation nppDataOperation) async {
    final Map<String, dynamic> response = await atRpcClient.call(nppDataOperation.atRpcPayload);
    return response;
  }

  Future<Set<Client>> getAllClients() async {
    final NppDataOperation operation = NppDataOperation.getAllClients();
    final Map<String, dynamic> response = await executeNppDataOperation(operation);
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
    final NppDataOperation nppDataOperation = NppDataOperation.getAllClientGroups();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
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
    final NppDataOperation nppDataOperation = NppDataOperation.getAllClientGroupMembers();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
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
    final NppDataOperation nppDataOperation = NppDataOperation.getAllDaemons();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
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
    final NppDataOperation nppDataOperation = NppDataOperation.getAllServices();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
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
    final NppDataOperation nppDataOperation = NppDataOperation.getAllServiceACLs();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
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

  Future<String> putClient(Client client) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putClient(client);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('clientId')) {
      throw Exception('clientId key not found in response map: $response');
    }
    final String clientId = response['clientId'];
    return clientId;
  }

  Future<String> putClientGroup(ClientGroup clientGroup) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putClientGroup(clientGroup);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('clientGroupId')) {
      throw Exception('clientGroupId key not found in response map: $response');
    }
    final String clientGroupId = response['clientGroupId'];
    return clientGroupId;
  }

  Future<String> putClientGroupMember(ClientGroupMember clientGroupMember) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putClientGroupMember(clientGroupMember);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('clientGroupMemberId')) {
      throw Exception('clientGroupMemberId key not found in response map: $response');
    }
    final String clientGroupMemberId = response['clientGroupMemberId'];
    return clientGroupMemberId;
  }

  Future<String> putDaemon(Daemon daemon) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putDaemon(daemon);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('daemonId')) {
      throw Exception('daemonId key not found in response map: $response');
    }
    final String daemonId = response['daemonId'];
    return daemonId;
  }

  Future<String> putService(Service service) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putService(service);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('serviceId')) {
      throw Exception('serviceId key not found in response map: $response');
    }
    final String serviceId = response['serviceId'];
    return serviceId;
  }

  Future<String> putServiceACL(ServiceACL serviceACL) async {
    final NppDataOperation nppDataOperation = NppDataOperation.putServiceACL(serviceACL);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('success')) {
      throw Exception('success key not found in response map: $response');
    }
    if(!response.containsKey('serviceACLId')) {
      throw Exception('serviceACLId key not found in response map: $response');
    }
    final String serviceACLId = response['serviceACLId'];
    return serviceACLId;
  }

  Future<bool> deleteClient(String clientId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteClient(clientId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<bool> deleteClientGroup(String clientGroupId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteClientGroup(clientGroupId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<bool> deleteClientGroupMember(String clientGroupMemberId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteClientGroupMember(clientGroupMemberId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<bool> deleteDaemon(String daemonId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteDaemon(daemonId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<bool> deleteService(String serviceId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteService(serviceId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<bool> deleteServiceACL(String serviceACLId) async {
    final NppDataOperation nppDataOperation = NppDataOperation.deleteServiceACL(serviceACLId);
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return response['success'] ?? false;
  }

  Future<Map<String, dynamic>> ping() async {
    final NppDataOperation nppDataOperation = NppDataOperation.ping();
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    if(!response.containsKey('status')) {
      throw Exception('status key not found in ping response: $response');
    }
    if(!response.containsKey('coreVersion')) {
      throw Exception('coreVersion key not found in ping response: $response');
    }
    if(!response.containsKey('binariesVersion')) {
      throw Exception('binariesVersion key not found in ping response: $response');
    }
    if(!response.containsKey('timestamp')) {
      throw Exception('timestamp key not found in ping response: $response');
    }
    return response;
  }

  Future<NPAAuthCheckResponse> simulate({
    required String daemonAtsign,
    required String deviceName,
    required String deviceGroupName,
    required String clientAtsign,
  }) async {
    final NppDataOperation nppDataOperation = NppDataOperation.simulate(
      daemonAtsign: daemonAtsign,
      deviceName: deviceName,
      deviceGroupName: deviceGroupName,
      clientAtsign: clientAtsign,
    );
    final Map<String, dynamic> response = await executeNppDataOperation(nppDataOperation);
    return NPAAuthCheckResponse.fromJson(response);
  }

}
