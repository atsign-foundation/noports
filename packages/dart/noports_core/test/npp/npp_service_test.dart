import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  late MockAtClient atClient;

  setUpAll(() {
    registerFallbackValue(AtKey());
    registerFallbackValue(GetRequestOptions());
  });

  setUp(() {
    atClient = MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn('@policy');
  });

  NppService service({
    String? eventLoggingAtSign,
    Duration heartbeatInterval = NppServiceDefaults.heartbeatInterval,
  }) => NppService(
    atClient: atClient,
    nppCache: NppCache(),
    managerAllowList: {'@policy'},
    binariesVersion: '0.0.0',
    homeDirectory: Directory.systemTemp.path,
    eventLoggingAtSign: eventLoggingAtSign,
    heartbeatInterval: heartbeatInterval,
  );

  group('NppService event logging Atsign', () {
    test('is handed to the policy request handler, normalised', () {
      final s = service(eventLoggingAtSign: 'Logs')..init();
      expect(s.npa.eventLoggingAtsign, '@logs');
    });

    test('is null when not supplied', () {
      final s = service()..init();
      expect(s.npa.eventLoggingAtsign, isNull);
    });

    test('is rejected when it is not a valid Atsign', () {
      expect(
        () => service(eventLoggingAtSign: '@a@b').init(),
        throwsA(isA<InvalidAtSignException>()),
      );
    });
  });

  group('NppService heartbeat interval', () {
    test('defaults to 60 s', () {
      expect(service().heartbeatInterval, const Duration(seconds: 60));
    });

    test('is refused under 30 s', () {
      expect(
        () => service(heartbeatInterval: const Duration(seconds: 29)).init(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('is accepted at 30 s', () {
      expect(
        () => service(heartbeatInterval: const Duration(seconds: 30)).init(),
        returnsNormally,
      );
    });
  });

  group('NppService.start() event logging config fetch', () {
    void getThrows(Object e) => when(
      () => atClient.get(
        any(),
        getRequestOptions: any(named: 'getRequestOptions'),
      ),
    ).thenThrow(e);

    test('not shared → notShared is true', () async {
      getThrows(AtKeyNotFoundException('key not found'));
      final s = service(eventLoggingAtSign: '@logs')..init();
      await expectLater(
        s.start(),
        throwsA(
          isA<EventLoggingConfigException>()
              .having((e) => e.notShared, 'notShared', isTrue)
              .having(
                (e) => e.toString(),
                'message',
                contains('has not yet shared'),
              ),
        ),
      );
    });

    test('any other failure → notShared is false', () async {
      getThrows(AtClientException.message('connection refused'));
      final s = service(eventLoggingAtSign: '@logs')..init();
      await expectLater(
        s.start(),
        throwsA(
          isA<EventLoggingConfigException>()
              .having((e) => e.notShared, 'notShared', isFalse)
              .having(
                (e) => e.toString(),
                'message',
                contains('Could not fetch'),
              ),
        ),
      );
    });
  });
}
