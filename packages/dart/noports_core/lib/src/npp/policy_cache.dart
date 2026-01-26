import 'package:at_utils/at_utils.dart';

import './models.dart';

class PolicyCache {
  static final AtSignLogger logger = AtSignLogger('PolicyCache');

  final Set<Client> _clients; // Client.atSign must be unique across all clients  
  final Set<ClientGroup> _clientGroups; 
  final Set<ClientGroupMember> _clientGroupMembers; 
  final Set<Daemon> _daemons; // Daemon.atSign must be unique across all daemons
  final Set<Service> _services; 
  final Set<ServiceACL> _serviceACLs;

  Set<Client> get clients => _clients;
  Set<ClientGroup> get clientGroups => _clientGroups;
  Set<ClientGroupMember> get clientGroupMembers => _clientGroupMembers;
  Set<Daemon> get daemons => _daemons;
  Set<Service> get services => _services;
  Set<ServiceACL> get serviceACLs => _serviceACLs;

  PolicyCache() :
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
      print('$clientAtSign is not a registered client in PolicyCache');
      return {};
    }
    if(client.id == null) {
      throw Exception('Client ${client.atSign} has null id which should never happen');
    }
    final String clientId = client.id!;
    Set<ClientGroupMember> matchedClientGroupMembers = _clientGroupMembers.where((clientGroupMember) => clientGroupMember.clientId == clientId).toSet();
    Set<ClientGroup> matchedClientGroups = {};
    for(final ClientGroupMember clientGroupMember in matchedClientGroupMembers) {
      final ClientGroup clientGroup = getClientGroupById(clientGroupMember.clientGroupId);
      matchedClientGroups.add(clientGroup);
    }
    return matchedClientGroups;
  }

  /// get* from PolicyCache
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
    Set<Daemon> candidates = _daemons.where((daemon) => daemon.atSign == atSign).toSet();
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
      print('No daemon found in PolicyCache with atSign $daemonAtSign');
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

  /// put* object into PolicyCache
  bool putClient(final Client client) {
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
    client.id ??= (_maxId(_clients) + 1).toString();
    return _clients.add(client);
  }

  bool putClientGroup(final ClientGroup clientGroup) {
    // ensure no duplicate client group names
    for(final ClientGroup cg in _clientGroups) {
      if(cg.name == clientGroup.name) {
        throw Exception('Found duplicate client group name ${clientGroup.name}');
      }
      if(cg.id != null && cg.id == clientGroup.id) {
        throw Exception('Found duplicate client group id ${clientGroup.id}');
      }
    }
    clientGroup.id ??= (_maxId(_clientGroups) + 1).toString();
    return _clientGroups.add(clientGroup);
  }

  bool putClientGroupMember(final ClientGroupMember clientGroupMember) {
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
    clientGroupMember.id ??= (_maxId(_clientGroupMembers) + 1).toString();
    return _clientGroupMembers.add(clientGroupMember);
  }

  bool putDaemon(final Daemon daemon) {
    // ensure policy cache only has one unique daemon atSign
    for(final Daemon d in _daemons) {
      if(d.atSign == daemon.atSign) {
        throw Exception('Found duplicate daemon atSign ${daemon.atSign}');
      }
      if(daemon.id != null && d.id == daemon.id) {
        throw Exception('Found duplicate daemon id ${daemon.id}');
      }
    }
    daemon.id ??= (_maxId(_daemons) + 1).toString();
    return _daemons.add(daemon);
  }

  bool putService(final Service service) {
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
    service.id ??= (_maxId(_services) + 1).toString();
    return _services.add(service);
  }

  bool putServiceACL(final ServiceACL serviceACL) {
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
    serviceACL.id ??= (_maxId(_serviceACLs) + 1).toString();
    return _serviceACLs.add(serviceACL);
  }

  int _maxId(final Set<PolicyEntry> entries) {
    int maxId = 0;
    for(final PolicyEntry entry in entries) {
      if(entry.id == null) {
        logger.warning('Encountered PolicyEntry with null id: $entry');
        continue;
      }
      final int entryId = int.tryParse(entry.id!) ?? 0;
      if(entryId > maxId) {
        maxId = entryId;
      }
    }
    return maxId;
  }

}

