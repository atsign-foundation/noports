import 'dart:convert';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';

const disabledByDefine = bool.fromEnvironment(
  'NPT_DISABLE_REGISTRAR_TLS_VERIFICATION',
);

void main() {
  group('Given NoPorts Desktop asking the registrar to verify an activation'
      ' code', () {
    late Directory dir;
    late String certificate;
    late HttpServer server;
    late List<String> received;

    setUp(() async {
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = overrides);
      dir = Directory.systemTemp.createTempSync('registrar_tls');
      certificate = '${dir.path}/certificate.pem';
      final key = '${dir.path}/key.pem';
      final made = Process.runSync('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        key,
        '-out',
        certificate,
        '-days',
        '1',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=DNS:localhost',
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');

      server = await HttpServer.bindSecure(
        'localhost',
        0,
        SecurityContext()
          ..useCertificateChain(certificate)
          ..usePrivateKey(key),
      );
      received = [];
      server.listen((request) async {
        received.add(await utf8.decodeStream(request));
        request.response.write('{"message":"Verified","cramkey":"x:y"}');
        await request.response.close();
      }, onError: (_) {});
    });

    tearDown(() async {
      await server.close(force: true);
      dir.deleteSync(recursive: true);
    });

    test("when the server it reaches presents a certificate the device doesn't"
        ' trust, then the request fails and the server receives nothing',
        () async {
      final util = ActivateUtil(
        registrarUrl: 'localhost:${server.port}',
        apiKey: 'api-key',
      );

      Object? failure;
      try {
        await util.verifyActivation(atsign: '@alice'.toAtsign(), otp: 'ABCD');
      } catch (e) {
        failure = e;
      }

      expect(received, isEmpty, reason: 'the server receives no request');
      expect(failure, isA<HandshakeException>());

      final pem = File(certificate).readAsStringSync().trim();
      final trusting = HttpClient()
        ..badCertificateCallback = (cert, host, port) => cert.pem.trim() == pem;
      final request = await trusting.postUrl(
        Uri.https('localhost:${server.port}', '/'),
      )
        ..write('control');
      await (await request.close()).drain<void>();
      trusting.close();
      expect(
        received,
        ['control'],
        reason: 'a client trusting the certificate reaches this server',
      );
    },
        skip: disabledByDefine
            ? 'runs without NPT_DISABLE_REGISTRAR_TLS_VERIFICATION'
            : false);

    test('when a debug build sets NPT_DISABLE_REGISTRAR_TLS_VERIFICATION, then'
        " the request reaches a server whose certificate the device doesn't"
        ' trust', () async {
      final util = ActivateUtil(
        registrarUrl: 'localhost:${server.port}',
        apiKey: 'api-key',
      );

      final result = await util.verifyActivation(
        atsign: '@alice'.toAtsign(),
        otp: 'ABCD',
      );

      expect(received, hasLength(1), reason: 'the server receives the request');
      expect(jsonDecode(received.single), containsPair('otp', 'ABCD'));
      expect(result.cramkey, 'y');
    },
        skip: disabledByDefine
            ? false
            : 'runs with'
                ' --dart-define=NPT_DISABLE_REGISTRAR_TLS_VERIFICATION=true');
  });
}
