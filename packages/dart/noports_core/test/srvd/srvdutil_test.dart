import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/srvd_util_mixin.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class FakeSrvd extends Fake with SrvdUtilMixin implements Srvd {
  @override
  AtSignLogger logger = AtSignLogger('FakeSrvd');
}

void main() {
  late Srvd srvd;

  setUp(() {
    srvd = FakeSrvd();
  });

  test('test notification subscription regex', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'test.${Srvd.namespace}';
  });

  test('accept session logging config notification', () {
    AtNotification n = AtNotification.empty()
      ..id = Uuid().v4()
      ..key =
          '@relay:logging.de0dbd91-3c42-4cb8-8630-23e51e78c8d3.sessions.sshrvd@service'
      ..to = '@relay'
      ..from = '@service'
      ..value = '';
    expect(srvd.wellFormedRequest(n, throwIfFalse: true), true);
  });

  test('srvd should accept notification in new request_ports format', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty()
      ..id = Uuid().v4()
      ..to = '@relay'
      ..from = '@alice'
      ..key = '@relay:request_ports.${Srvd.namespace}@alice'
      ..value = '';
    expect(srvd.wellFormedRequest(notification, throwIfFalse: true), true);
  });
}
