import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import '../../sshnp_mocks.dart';
import 'openssh_ssh_session_handler_mocks.dart';

void main() {
  group('SshnpOpensshSshSessionHandler', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late MockSshnpdChannel mockSshnpChannel;
    late MockSrvdChannel mockSrvdChannel;
    late StubbedSshnp stubbedSshnp;

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      mockSshnpChannel = MockSshnpdChannel();
      mockSrvdChannel = MockSrvdChannel();

      // Mocked SshnpCore Constructor calls
      registerFallbackValue(AtClientPreference());
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.localPort).thenReturn(0);
      when(() => mockParams.verbose).thenReturn(false);
      when(() => mockAtClient.getPreferences()).thenReturn(null);
      when(() => mockAtClient.setPreferences(any())).thenReturn(null);

      stubbedSshnp = StubbedSshnp(
        atClient: mockAtClient,
        params: mockParams,
        sshnpdChannel: mockSshnpChannel,
        srvdChannel: mockSrvdChannel,
      );

      // Mocked SshnpCore Initialization calls
      // TODO srvd channel mock calls
      // TODO sshnpd channel mock calls
    });

    test('implements SshnpSshSessionHandler<Process?>', () {
      expect(stubbedSshnp, isA<SshSessionHandler<Process?>>());
    }); // test public API
    test(
        'when the tunnel username has a space, then it reaches ssh as one'
        ' argument', () async {
      final startProcess = StartProcessStub();
      final process = MockProcess();
      when(() => process.stdout).thenAnswer((_) => Stream.empty());
      when(() => process.stderr).thenAnswer((_) => Stream.empty());
      when(() => process.exitCode).thenAnswer((_) async => 0);
      when(() => startProcess(any(), any())).thenAnswer((_) async => process);
      when(() => mockParams.remoteSshdPort).thenReturn(22);
      when(() => mockParams.addForwardsToTunnel).thenReturn(false);
      stubbedSshnp
        ..tunnelUsername = 'a b'
        ..stubSshnpOpensshSshSessionHandler(
          stubbedStartInitialTunnel: StartInitialTunnelStub(),
          stubbedStartProcess: startProcess,
        );

      await stubbedSshnp.startInitialTunnelSession(
        ephemeralKeyPairIdentifier: 'the-key',
        localRvPort: 1234,
      );

      final args = verify(() => startProcess(any(), captureAny()))
          .captured
          .single as List<String>;
      expect(args, [
        'a b@localhost',
        '-p', '1234',
        '-i', 'the-key',
        '-L', '${stubbedSshnp.localPort}:localhost:22',
        '-o', 'LogLevel=VERBOSE',
        '-t', '-t',
        '-o', 'StrictHostKeyChecking=accept-new',
        '-o', 'IdentitiesOnly=yes',
        '-o', 'BatchMode=yes',
        '-o', 'ExitOnForwardFailure=yes',
        '-n',
        '-f',
        'sleep', '15',
      ]);
    }, testOn: '!windows');

    test(
        'when the tunnel ssh exits non-zero, then startInitialTunnelSession'
        ' throws SshnpError with the exit code and ssh stderr', () async {
      final startProcess = StartProcessStub();
      final process = MockProcess();
      when(() => process.stdout).thenAnswer((_) => Stream.empty());
      when(() => process.stderr).thenAnswer(
        (_) => Stream.value(utf8.encode('Permission denied (publickey).\n')),
      );
      when(() => process.exitCode).thenAnswer((_) async => 255);
      when(() => startProcess(any(), any())).thenAnswer((_) async => process);
      when(() => mockParams.remoteSshdPort).thenReturn(22);
      when(() => mockParams.addForwardsToTunnel).thenReturn(false);
      stubbedSshnp
        ..tunnelUsername = 'nosuchuser'
        ..stubSshnpOpensshSshSessionHandler(
          stubbedStartInitialTunnel: StartInitialTunnelStub(),
          stubbedStartProcess: startProcess,
        );

      await expectLater(
        stubbedSshnp.startInitialTunnelSession(
          ephemeralKeyPairIdentifier: 'the-key',
          localRvPort: 1234,
        ),
        throwsA(
          isA<SshnpError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('255'), contains('Permission denied (publickey)')),
          ),
        ),
      );
    }, testOn: '!windows');

    Future<void> startFailingTunnel({
      required Stream<List<int>> stderr,
      required int exitCode,
    }) {
      final startProcess = StartProcessStub();
      final process = MockProcess();
      when(() => process.stdout).thenAnswer((_) => Stream.empty());
      when(() => process.stderr).thenAnswer((_) => stderr);
      when(() => process.exitCode).thenAnswer((_) async => exitCode);
      when(() => startProcess(any(), any())).thenAnswer((_) async => process);
      when(() => mockParams.remoteSshdPort).thenReturn(22);
      when(() => mockParams.addForwardsToTunnel).thenReturn(false);
      stubbedSshnp
        ..tunnelUsername = 'nosuchuser'
        ..stubSshnpOpensshSshSessionHandler(
          stubbedStartInitialTunnel: StartInitialTunnelStub(),
          stubbedStartProcess: startProcess,
        );
      return stubbedSshnp.startInitialTunnelSession(
        ephemeralKeyPairIdentifier: 'the-key',
        localRvPort: 1234,
      );
    }

    test(
        'when the tunnel ssh writes its stderr after it has exited non-zero,'
        ' then the SshnpError still carries that stderr', () async {
      final stderr = StreamController<List<int>>();
      unawaited(Future.delayed(Duration(milliseconds: 100), () async {
        stderr.add(utf8.encode('Permission denied (publickey).\n'));
        await stderr.close();
      }));

      await expectLater(
        startFailingTunnel(stderr: stderr.stream, exitCode: 255),
        throwsA(
          isA<SshnpError>().having(
            (e) => e.toString(),
            'message',
            contains('Permission denied (publickey)'),
          ),
        ),
      );
    }, testOn: '!windows');

    test(
        'when the tunnel ssh is ended by a signal (negative exit code),'
        ' then startInitialTunnelSession throws SshnpError', () async {
      await expectLater(
        startFailingTunnel(stderr: Stream.empty(), exitCode: -15),
        throwsA(
          isA<SshnpError>().having(
            (e) => e.toString(),
            'message',
            contains('-15'),
          ),
        ),
      );
    }, testOn: '!windows');
  }); // group SshnpOpensshSshSessionHandler
}
