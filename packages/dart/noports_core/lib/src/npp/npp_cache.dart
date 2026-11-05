import 'package:at_commons/atsign.dart';
import 'package:at_utils/at_utils.dart';
import 'package:uuid/uuid.dart';

import 'package:noports_core/src/common/validation_utils.dart';

import './models.dart';

/// A new policy entry id. Ids are random, so npp never gives one out twice.
String newPolicyEntryId() => const Uuid().v4();

class NppCache {
  static final AtSignLogger logger = AtSignLogger('NppCache');

  final Set<Client> _clients; // Client.atSign must be unique across all clients
  final Set<ClientGroup> _clientGroups;
  final Set<ClientGroupMember> _clientGroupMembers;
  final Set<Daemon> _daemons; // Daemon.atSign must be unique across all daemons
  final Set<Service> _services;
  final Set<ServiceACL> _serviceACLs;
  final CanonicalAtsigns _canonical = CanonicalAtsigns();

  Set<Client> get clients => _clients;
  Set<ClientGroup> get clientGroups => _clientGroups;
  Set<ClientGroupMember> get clientGroupMembers => _clientGroupMembers;
  Set<Daemon> get daemons => _daemons;
  Set<Service> get services => _services;
  Set<ServiceACL> get serviceACLs => _serviceACLs;

  NppCache() :
    _clients = {},
    _clientGroups = {},
    _clientGroupMembers = {},
    _daemons = {},
    _services = {},
    _serviceACLs = {};

  // *.client.policy.sshnp --> a client (e.g. "@colin", "Colin")
  // *.client_group.policy.sshnp --> a client group (e.g. client.id, "Atsign Engineers")
  // *.client_group_members.policy.sshnp --> maps client to a client group (e.g. client.id, client_group.id)
  // *.daemon.policy.sshnp --> a daemon (e.g. "@device")
  // *.service.policy.sshnp --> a device (e.g. daemon.id, "deviceName")
  // *.service_acl.policy.sshnp --> a service ACL (e.g. service.id, client_group.id, "localhost:22")

  Set<ServiceACL> findMatchedServiceACLs({
    required final String clientAtSign,
    required final String daemonAtSign,
    required final String deviceName,
    required final String deviceGroupName}) {
    // Set of services that match the given daemonAtSign + deviceName and/or deviceGroupName
    Service? matchedService = findMatchedService(daemonAtSign: daemonAtSign, deviceName: deviceName, deviceGroupName: deviceGroupName);
    if(matchedService == null) {
      logger.info('No matched services were found for $daemonAtSign | $deviceName | $deviceGroupName');
      return {};
    }
    // Set of ClientGroups that this clientAtSign is part of.
    Set<ClientGroup> matchedClientGroups = findMatchedClientGroups(clientAtSign: clientAtSign);
    if(matchedClientGroups.isEmpty) {
      logger.info('No matched client groups were found for $clientAtSign');
      return {};
    }

    // Set of Service ACLs that match this Client + Service that we are trying to find
    Set<ServiceACL> matchedServiceACLs = {};
    for(final ServiceACL serviceACL in _serviceACLs) {
      for(final ClientGroup clientGroup in matchedClientGroups) {
        if(serviceACL.clientGroupId == clientGroup.id) {
          if(matchedService.id == serviceACL.serviceId) {
            matchedServiceACLs.add(serviceACL);
          }
        }
      }
    }
    return matchedServiceACLs;
  }

  Service? findMatchedService({
    required final String daemonAtSign,
    required final String deviceName,
    required final String deviceGroupName}) {
    Set<Service> servicesThatMatchDaemonAtSign = getServicesByDaemonAtSign(daemonAtSign);
    for(final Service s in servicesThatMatchDaemonAtSign) {
      if(s.deviceName == deviceName && s.deviceGroupName == deviceGroupName) {
        return s;
      }
    }
    return null;
  }

  // Returns Set of ClientGroups that this clientAtSign may be part of
  // E.g. "@alice" may be part of group "Engineers", "Marketing", ...
  // Length of set returned is >= 0
  Set<ClientGroup> findMatchedClientGroups({required final String clientAtSign}) {
    Client? client = getClientByAtSign(clientAtSign);
    if(client == null) {
      print('$clientAtSign is not a registered client in NppCache');
      return {};
    }
    if(client.id == null) {
      throw Exception('Client ${client.atSign} has null id which should never happen');
    }
    final String clientId = client.id!;
    Set<ClientGroupMember> matchedClientGroupMembers = _clientGroupMembers.where((clientGroupMember) => clientGroupMember.clientId == clientId).toSet();
    Set<ClientGroup> matchedClientGroups = {};
    for(final ClientGroupMember clientGroupMember in matchedClientGroupMembers) {
      final ClientGroup? clientGroup = _clientGroups
          .where((cg) => cg.id == clientGroupMember.clientGroupId)
          .firstOrNull;
      if (clientGroup != null) {
        matchedClientGroups.add(clientGroup);
      }
    }
    return matchedClientGroups;
  }

  /// Whether a service ACL covers any service of the daemon [daemonAtSign].
  bool hasServiceACLsForDaemon(final Atsign daemonAtSign) {
    for (final Daemon daemon in _daemons) {
      if (daemon.id == null || _canonical.of(daemon.atSign) != daemonAtSign) {
        continue;
      }
      for (final Service service in getServicesByDaemonId(daemon.id!)) {
        if (service.id != null &&
            getServiceACLsByServiceID(service.id!).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// get* from NppCache
  Set<ServiceACL> getServiceACLsByServiceID(final String serviceId) {
    return _serviceACLs.where((serviceACL) => serviceACL.serviceId == serviceId).toSet();
  }

  Set<ServiceACL> getServiceACLsByClientGroupId(final String clientGroupId) {
    return _serviceACLs.where((serviceACL) => serviceACL.clientGroupId == clientGroupId).toSet();
  }

  Set<Service> getServicesByDaemonId(final String daemonId) {
    return _services.where((service) => service.daemonId == daemonId).toSet();
  }

  Daemon? getDaemonByAtSign(final String atSign) {
    final asked = canonicalAtsign(atSign);
    Set<Daemon> candidates = _daemons
        .where((daemon) => asked != null && _canonical.of(daemon.atSign) == asked)
        .toSet();
    if(candidates.length > 1) {
      throw Exception('Found more than one Daemon object with atSign $atSign');
    }
    if(candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  Set<ClientGroupMember> getClientGroupMembersByClientId(final String clientId) {
    return _clientGroupMembers.where((clientGroupMember) => clientGroupMember.clientId == clientId).toSet();
  }

  Set<ClientGroupMember> getClientGroupMembersByClientGroupId(final String clientGroupId) {
    return _clientGroupMembers.where((clientGroupMember) => clientGroupMember.clientGroupId == clientGroupId).toSet();
  }

  Set<ClientGroup> getClientGroupsByName(final String clientGroupName) {
    return _clientGroups.where((clientGroup) => clientGroup.name == clientGroupName).toSet();
  }

  Set<Service> getServicesByDaemonAtSign(final String daemonAtSign) {
    Daemon? daemon = getDaemonByAtSign(daemonAtSign);
    if(daemon == null) {
      print('No daemon found in NppCache with atSign $daemonAtSign');
      return {};
    }
    if(daemon.id == null) {
      throw Exception('Daemon with atSign $daemonAtSign has null id which should never happen');
    }
    final String daemonId = daemon.id!;
    Set<Service> servicesThatMatchDaemonAtSign = getServicesByDaemonId(daemonId); // services that match this daemon atSign
    return servicesThatMatchDaemonAtSign;
  }

  Client? getClientByAtSign(final String clientAtSign) {
    Set<Client> candidates = _clients.where((client) => client.atSign == clientAtSign).toSet();
    if(candidates.length > 1) {
      throw Exception('Found more than one client with the same atSign in policy cache which should never happen');
    }
    if(candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  Client getClientById(final String clientId) {
    return _clients.where((c) => c.id == clientId).first;
  }

  ClientGroup getClientGroupById(final String clientGroupId) {
    return _clientGroups.where((cg) => cg.id == clientGroupId).first;
  }

  ClientGroupMember getClientGroupMemberById(final String clientGroupMemberId) {
    return _clientGroupMembers.where((cgm) => cgm.id == clientGroupMemberId).first;
  }

  Daemon getDaemonById(final String daemonId) {
    return _daemons.where((daemon) => daemon.id == daemonId).first;
  }

  Service getServiceById(final String serviceId) {
    return _services.where((service) => service.id == serviceId).first;
  }

  ServiceACL getServiceACLById(final String serviceACLId) {
    return _serviceACLs.where((serviceACL) => serviceACL.id == serviceACLId).first;
  }

  /// put* object into NppCache. Each checkPut* throws if that object can't be
  /// put, so a caller can check before saving it anywhere else.
  void checkPutClient(final Client client) {
    // ensure no other clients exist with the same atSign
    for(final Client c in _clients) {
      if(c.atSign == client.atSign) {
        throw Exception('Attempted to add a new client with atSign '
          '${client.atSign} when that atSign already exists in the policy '
          'cache. It\'s very important to maintain 1 atSign = 1 client '
          'property of policy cache');
      }
      if(client.id != null && c.id == client.id) {
        throw Exception('Attempted to add a new client with id '
          '${client.id} when that id already exists in the policy cache.');
      }
    }
  }

  bool putClient(final Client client) {
    checkPutClient(client);
    client.id ??= newPolicyEntryId();
    return _clients.add(client);
  }

  void checkPutClientGroup(final ClientGroup clientGroup) {
    // ensure no duplicate client group names
    for(final ClientGroup cg in _clientGroups) {
      if(cg.name == clientGroup.name) {
        throw Exception('Found duplicate client group name ${clientGroup.name}');
      }
      if(cg.id != null && cg.id == clientGroup.id) {
        throw Exception('Found duplicate client group id ${clientGroup.id}');
      }
    }
  }

  bool putClientGroup(final ClientGroup clientGroup) {
    checkPutClientGroup(clientGroup);
    clientGroup.id ??= newPolicyEntryId();
    return _clientGroups.add(clientGroup);
  }

  void checkPutClientGroupMember(final ClientGroupMember clientGroupMember) {
    // ensure no duplicate client group member (Client.id, ClientGroup.id)
    for(final ClientGroupMember cgm in _clientGroupMembers) {
      if(cgm.clientId == clientGroupMember.clientId && cgm.clientGroupId == clientGroupMember.clientGroupId) {
        throw Exception('Found duplicate value for ${clientGroupMember.clientId}'
          ' and ${clientGroupMember.clientGroupId}');
      }
      if(cgm.id != null && cgm.id == clientGroupMember.id) {
        throw Exception('Found duplicate client group member id ${clientGroupMember.id}');
      }
    }
  }

  bool putClientGroupMember(final ClientGroupMember clientGroupMember) {
    checkPutClientGroupMember(clientGroupMember);
    clientGroupMember.id ??= newPolicyEntryId();
    return _clientGroupMembers.add(clientGroupMember);
  }

  void checkPutDaemon(final Daemon daemon) {
    // ensure policy cache only has one unique daemon atSign
    for(final Daemon d in _daemons) {
      if(d.atSign == daemon.atSign) {
        throw Exception('Found duplicate daemon atSign ${daemon.atSign}');
      }
      if(daemon.id != null && d.id == daemon.id) {
        throw Exception('Found duplicate daemon id ${daemon.id}');
      }
    }
  }

  bool putDaemon(final Daemon daemon) {
    checkPutDaemon(daemon);
    daemon.id ??= newPolicyEntryId();
    return _daemons.add(daemon);
  }

  void checkPutService(final Service service) {
    // ensure no duplicate services
    for(final Service s in _services) {
      if(s.daemonId == service.daemonId &&
        s.deviceName == service.deviceName &&
        s.deviceGroupName == service.deviceGroupName) {
        throw Exception('Found duplicate service daemonId: ${service.daemonId} '
          'deviceName: ${service.deviceName} '
          'deviceGroupName: ${service.deviceGroupName}');
      }
      if(service.id != null && s.id == service.id) {
        throw Exception('Found duplicate service id ${service.id}');
      }
    }
  }

  bool putService(final Service service) {
    checkPutService(service);
    service.id ??= newPolicyEntryId();
    return _services.add(service);
  }

  void checkPutServiceACL(final ServiceACL serviceACL) {
    for(final ServiceACL sa in _serviceACLs) {
      if(sa.clientGroupId == serviceACL.clientGroupId &&
        sa.serviceId == serviceACL.serviceId &&
        sa.permitOpen == serviceACL.permitOpen) {
        throw Exception('Found duplicate service ACL for clientGroupId: '
          '${serviceACL.clientGroupId} serviceId: ${serviceACL.serviceId}'
          ' permitOpen: ${serviceACL.permitOpen}');
      }
      if(sa.id == null) {
          throw Exception('Encountered ServiceACL with null id: $sa, '
            'which should never happen');
      }
      if(sa.id == serviceACL.id) {
        throw Exception('Found duplicate service ACL id ${serviceACL.id}');
      }
    }
   }

  bool putServiceACL(final ServiceACL serviceACL) {
    checkPutServiceACL(serviceACL);
    serviceACL.id ??= newPolicyEntryId();
    return _serviceACLs.add(serviceACL);
  }

  /// The rules [entry] names that this cache doesn't hold, each as
  /// `<kind> with id <id>`. Empty when it names none, or all are here.
  List<String> missingReferences(final PolicyEntry entry) {
    final List<String> missing = [];
    void need(
        final Set<PolicyEntry> rules, final String kind, final String id) {
      if (!rules.any((rule) => rule.id == id)) {
        missing.add('$kind with id $id');
      }
    }

    switch (entry) {
      case ClientGroupMember member:
        need(_clients, 'Client', member.clientId);
        need(_clientGroups, 'ClientGroup', member.clientGroupId);
      case Service service:
        need(_daemons, 'Daemon', service.daemonId);
      case ServiceACL serviceACL:
        need(_services, 'Service', serviceACL.serviceId);
        need(_clientGroups, 'ClientGroup', serviceACL.clientGroupId);
    }
    return missing;
  }

  /// Removes every rule naming a rule this cache doesn't hold, services before
  /// the service ACLs naming them, and returns each one removed with its
  /// kind and [missingReferences].
  List<(String, PolicyEntry, List<String>)> removeRulesNamingMissing() {
    final List<(String, PolicyEntry, List<String>)> removed = [];
    final Map<String, Set<PolicyEntry>> rulesByKind = {
      'Service': _services,
      'ServiceACL': _serviceACLs,
      'ClientGroupMember': _clientGroupMembers,
    };
    rulesByKind.forEach((kind, rules) {
      for (final PolicyEntry rule in rules.toList()) {
        final List<String> missing = missingReferences(rule);
        if (missing.isNotEmpty) {
          rules.remove(rule);
          removed.add((kind, rule, missing));
        }
      }
    });
    return removed;
  }

  bool deleteClient(final String clientId) {
    final Client client = getClientById(clientId);
    return _clients.remove(client);
  }

  bool deleteClientGroup(final String clientGroupId) {
    final ClientGroup clientGroup = getClientGroupById(clientGroupId);
    return _clientGroups.remove(clientGroup);
  }

  bool deleteClientGroupMember(final String clientGroupMemberId) {
    final ClientGroupMember clientGroupMember = getClientGroupMemberById(clientGroupMemberId);
    return _clientGroupMembers.remove(clientGroupMember);
  }

  bool deleteDaemon(final String daemonId) {
    final Daemon daemon = getDaemonById(daemonId);
    return _daemons.remove(daemon);
  }

  bool deleteService(final String serviceId) {
    final Service service = getServiceById(serviceId);
    return _services.remove(service);
  }

  bool deleteServiceACL(final String serviceACLId) {
    final ServiceACL serviceACL = getServiceACLById(serviceACLId);
    return _serviceACLs.remove(serviceACL);
  }

}
