import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/npp.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  late MockAtClient atClient;

  setUp(() {
    atClient = MockAtClient();
    when(() => atClient.getCurrentAtSign()).thenReturn('@policy');
  });

  NppService service({String? eventLoggingAtSign}) => NppService(
    atClient: atClient,
    nppCache: NppCache(),
    managerAllowList: {'@policy'},
    binariesVersion: '0.0.0',
    homeDirectory: Directory.systemTemp.path,
    eventLoggingAtSign: eventLoggingAtSign,
  );

  group('NppService event logging atSign', () {
    test('is handed to the policy request handler, normalised', () {
      final s = service(eventLoggingAtSign: 'Logs')..init();
      expect((s.npa as NPAImpl).eventLoggingAtsign, '@logs');
    });

    test('is null when not supplied', () {
      final s = service()..init();
      expect((s.npa as NPAImpl).eventLoggingAtsign, isNull);
    });

    test('is rejected when it is not a valid atSign', () {
      expect(
        () => service(eventLoggingAtSign: '@a@b').init(),
        throwsA(isA<InvalidAtSignException>()),
      );
    });
  });
}
