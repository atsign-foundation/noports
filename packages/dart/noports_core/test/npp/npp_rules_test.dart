import 'package:at_client/at_client.dart';
import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

void main() {
  group('Given npp rules', () {
    test(
        "a daemon has rules when a service ACL names its atSign, and"
        ' otherwise not', () {
      final cache = NppCache();
      cache.daemons
        ..add(Daemon(id: 'd1', atSign: '@daemon'))
        ..add(Daemon(id: 'd2', atSign: '@other'));
      cache.services
        ..add(Service(
          id: 's1',
          daemonId: 'd1',
          deviceName: 'device',
          deviceGroupName: '__none__',
        ))
        ..add(Service(
          id: 's2',
          daemonId: 'd2',
          deviceName: 'device',
          deviceGroupName: '__none__',
        ));
      cache.serviceACLs.add(ServiceACL(
        id: 'a1',
        serviceId: 's1',
        clientGroupId: 'g1',
        permitOpen: 'localhost:22',
      ));
      final handler = NppRequestHandler(nppCache: cache);

      expect(handler.hasRulesFor('@daemon'.toAtsign()), isTrue);
      expect(
        handler.hasRulesFor('@other'.toAtsign()),
        isFalse,
        reason: 'a service with no ACL is not a rule',
      );
      expect(handler.hasRulesFor('@nobody'.toAtsign()), isFalse);
    });
  });
}
