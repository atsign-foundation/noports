import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

void main() {
  late NppCache cache;
  late Client c1;
  late Client c2;
  late Client c3;
  late Client c4;
  late Client c5;
  late Client c6;

  late ClientGroup cg1;
  late ClientGroup cg2;

  late ClientGroupMember cgm1, cgm2, cgm3, cgm4, cgm5, cgm6, cgm7;

  late Daemon d1, d2;

  late Service s1, s2, s3, s4, s5, s6;

  late ServiceACL sa1, sa2, sa3, sa4, sa5, sa6, sa7, sa8, sa9, sa10, sa11, sa12;

  setUpAll(() {
      cache = NppCache();

      c1 = Client(id: 'c1', name: 'Alice', atSign: '@alice');
      c2 = Client(id: 'c2', name: 'Bob', atSign: '@bob');
      c3 = Client(id: 'c3', name: 'Charlie', atSign: '@charlie');
      c4 = Client(id: 'c4', name: 'Delta', atSign: '@delta');
      c5 = Client(id: 'c5', name: 'Echo', atSign: '@echo');
      c6 = Client(id: 'c6', name: 'J', atSign: '@j');

      cg1 = ClientGroup(id: 'cg1', name: 'Engineers');
      cg2 = ClientGroup(id: 'cg2', name: 'Marketing');

      cgm1 = ClientGroupMember(id: 'cgm1', clientId: c1.id!, clientGroupId: cg1.id!); 
      cgm2 = ClientGroupMember(id: 'cgm2', clientId: c2.id!, clientGroupId: cg1.id!); 
      cgm3 = ClientGroupMember(id: 'cgm3', clientId: c3.id!, clientGroupId: cg1.id!);
      cgm4 = ClientGroupMember(id: 'cgm4', clientId: c4.id!, clientGroupId: cg2.id!);
      cgm5 = ClientGroupMember(id: 'cgm5', clientId: c5.id!, clientGroupId: cg2.id!);
      cgm6 = ClientGroupMember(id: 'cgm6', clientId: c6.id!, clientGroupId: cg1.id!);
      cgm7 = ClientGroupMember(id: 'cgm7', clientId: c6.id!, clientGroupId: cg2.id!);

      d1 = Daemon(id: 'd1', atSign: '@lxc');
      d2 = Daemon(id: 'd2', atSign: '@vps');

      s1 = Service(id: 's1', daemonId: d1.id!, deviceName: 'gcp', deviceGroupName: '__none__');
      s2 = Service(id: 's2', daemonId: d1.id!, deviceName: 'azure', deviceGroupName: '__none__');
      s3 = Service(id: 's3', daemonId: d1.id!, deviceName: 'oci', deviceGroupName: '__none__');
      s4 = Service(id: 's4', daemonId: d2.id!, deviceName: 'rv_am', deviceGroupName: 'relays');
      s5 = Service(id: 's5', daemonId: d2.id!, deviceName: 'rv_ap', deviceGroupName: 'relays');
      s6 = Service(id: 's6', daemonId: d2.id!, deviceName: 'rv_eu', deviceGroupName: 'relays');

      sa1 = ServiceACL(id: 'sa1', serviceId: s1.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa2 = ServiceACL(id: 'sa2', serviceId: s1.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:3389');
      sa3 = ServiceACL(id: 'sa3', serviceId: s2.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa4 = ServiceACL(id: 'sa4', serviceId: s2.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:3389');
      sa5 = ServiceACL(id: 'sa5', serviceId: s3.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa6 = ServiceACL(id: 'sa6', serviceId: s3.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:3389');
      sa7 = ServiceACL(id: 'sa7', serviceId: s4.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa8 = ServiceACL(id: 'sa8', serviceId: s5.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa9 = ServiceACL(id: 'sa9', serviceId: s6.id!, clientGroupId: cg1.id!, permitOpen: 'localhost:22');
      sa10 = ServiceACL(id: 'sa10', serviceId: s4.id!, clientGroupId: cg2.id!, permitOpen: 'localhost:22');
      sa11 = ServiceACL(id: 'sa11', serviceId: s5.id!, clientGroupId: cg2.id!, permitOpen: 'localhost:22');
      sa12 = ServiceACL(id: 'sa12', serviceId: s6.id!, clientGroupId: cg2.id!, permitOpen: 'localhost:22');

      cache.putClient(c1);
      cache.putClient(c2);
      cache.putClient(c3);
      cache.putClient(c4);
      cache.putClient(c5);
      cache.putClient(c6);
      cache.putClientGroup(cg1);
      cache.putClientGroup(cg2);
      cache.putClientGroupMember(cgm1);
      cache.putClientGroupMember(cgm2);
      cache.putClientGroupMember(cgm3);
      cache.putClientGroupMember(cgm4);
      cache.putClientGroupMember(cgm5);
      cache.putClientGroupMember(cgm6);
      cache.putClientGroupMember(cgm7);
      cache.putDaemon(d1);
      cache.putDaemon(d2);
      cache.putService(s1);
      cache.putService(s2);
      cache.putService(s3);
      cache.putService(s4);
      cache.putService(s5);
      cache.putService(s6);
      cache.putServiceACL(sa1);
      cache.putServiceACL(sa2);
      cache.putServiceACL(sa3);
      cache.putServiceACL(sa4);
      cache.putServiceACL(sa5);
      cache.putServiceACL(sa6);
      cache.putServiceACL(sa7);
      cache.putServiceACL(sa8);
      cache.putServiceACL(sa9);
      cache.putServiceACL(sa10);
      cache.putServiceACL(sa11);
      cache.putServiceACL(sa12);
  });

  group('findMatchedServiceACLs', () {
      test('Check that @alice has two ServiceACLs with @lxc deviceName=gcp', () {
          final String clientAtSign = c1.atSign;
          final String daemonAtSign = d1.atSign;
          final String deviceName = s1.deviceName;
          final String deviceGroupName = s1.deviceGroupName;
          Set<ServiceACL> serviceACLs = cache.findMatchedServiceACLs(clientAtSign: clientAtSign, daemonAtSign: daemonAtSign, deviceName: deviceName, deviceGroupName: deviceGroupName);
          // print(serviceACLs.length);
          // for(final ServiceACL serviceACL in serviceACLs) {
          //   print(serviceACL.toJson());
          // }
          expect(serviceACLs.length, 2);
          expect(serviceACLs.contains(sa1), true);
          expect(serviceACLs.contains(sa2), true);
          });
      });
  group('findMatchedService', () {
      test('Check that one service is matched to @lxc with deviceName = azure, deviceGroupName = __none__', () {
          final String daemonAtSign = d1.atSign;
          final String deviceName = s2.deviceName;
          final String deviceGroupName = s2.deviceGroupName;
          final Service? matchedService = cache.findMatchedService(daemonAtSign: daemonAtSign, deviceName: deviceName, deviceGroupName: deviceGroupName);
          // for(final Service s in matchedServices) {
          // print(s.toJson());
          // }
          expect(matchedService, s2);
          });
      test('Check that multiple services are returned when @lxc ', () {});
      });
  group('findMatchedClientGroups', () {
      test('Check that @j is part of Engineers and Marketing', () {
          final String clientAtSign = c6.atSign;
          final Set<ClientGroup> matchedClientGroups = cache.findMatchedClientGroups(clientAtSign: clientAtSign);
          expect(matchedClientGroups.length, 2);
          expect(matchedClientGroups.contains(cg1), true);
          expect(matchedClientGroups.contains(cg2), true);
        });
      test('Check that @alice is part of Engineers', () {
          final String clientAtSign = c1.atSign;
          final Set<ClientGroup> matchedClientGroups = cache.findMatchedClientGroups(clientAtSign: clientAtSign);
          expect(matchedClientGroups.length, 1);
          expect(matchedClientGroups.contains(cg1), true);
        });
    });
    
}

