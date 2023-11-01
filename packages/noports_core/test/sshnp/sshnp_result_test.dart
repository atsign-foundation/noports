import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

class MockProcess extends Mock implements Process {}

class MockSocketConnector extends Mock implements SocketConnector {}

void main() {
  group('SSHNPResult', () {
    group('Subclass Confirmation', () {
      test('SSHNPSuccess test', () {
        expect(SshnpSuccess(), isA<SshnpResult>());
      });
      test('SSHNPCommand test', () {
        final res = SshnpCommand(host: 'localhost', localPort: 22);
        expect(res, isA<SshnpSuccess>());
      });
      test('SSHNPNoOpSuccess test', () {
        final res = SshnpNoOpSuccess();
        expect(res, isA<SshnpResult>());
        expect(res, isA<SshnpSuccess>());
      });
      test('SSHNPFailure test', () {
        expect(SshnpFailure(), isA<SshnpResult>());
      });
      test('SSHNPError test', () {
        final res = SshnpError('error message');
        expect(res, isA<SshnpResult>());
        expect(res, isA<SshnpFailure>());
      });
    }); // group('Subclass Confirmation')
    group('SSHNPError', () {
      late StackTrace stackTrace;
      late SshnpError error;
      setUp(() {
        stackTrace = StackTrace.current;
        error =
            SshnpError('myMessage', error: 'myError', stackTrace: stackTrace);
      });
      test('SSHNPError.toString() test', () {
        expect(error.toString(), equals('myMessage'));
      });
      test('SSHNPError.error test', () {
        expect(error.error, equals('myError'));
      });
      test('SSHNPError.stackTrace test', () {
        expect(error.stackTrace, equals(stackTrace));
      });
    }); // group('SSHNPError')
    group('SSHNPCommand', () {
      test('SSHNPCommand.toString() test', () {
        final command = SshnpCommand(
          localPort: 22,
          host: 'localhost',
          remoteUsername: 'myUsername',
          localSshOptions: ['-L 127.0.0.1:8080:127.0.0.1:80'],
          privateKeyFileName: '~/.ssh/myPrivateKeyFile',
        );
        expect(
          command.toString(),
          equals(
            'ssh -p 22 ${optionsWithPrivateKey.join(' ')} '
            '-L 127.0.0.1:8080:127.0.0.1:80 '
            'myUsername@localhost '
            '-i ~/.ssh/myPrivateKeyFile',
          ),
        );
      });
      test('SSHNPCommand.connectionBean test', () {
        SshnpCommand<String> command = SshnpCommand(
          host: 'localhost',
          localPort: 22,
          connectionBean: 'myBean',
        );
        expect(command.connectionBean, equals('myBean'));
      });
      test('static SSHNPCommand.shouldIncludePrivateKey test', () {
        expect(SshnpCommand.shouldIncludePrivateKey(null), isFalse);
        expect(SshnpCommand.shouldIncludePrivateKey(''), isFalse);
        // it is not the responsibility of this class to validate whether the private key file name is valid
        // it purely wants to know whether there is a value or not
        expect(SshnpCommand.shouldIncludePrivateKey('asdfkjsdflkjd'), isTrue);
      });
      test('SSHNPCommand.args test', () {
        final command = SshnpCommand(
          localPort: 22,
          host: 'localhost',
          remoteUsername: 'myUsername',
          localSshOptions: ['-L 127.0.0.1:8080:127.0.0.1:80'],
          privateKeyFileName: '~/.ssh/myPrivateKeyFile',
        );
        expect(
          command.args,
          equals([
            '-p 22',
            ...optionsWithPrivateKey,
            '-L 127.0.0.1:8080:127.0.0.1:80',
            'myUsername@localhost',
            '-i',
            '~/.ssh/myPrivateKeyFile',
          ]),
        );
      });
    }); // group('SSHNPCommand')
    group('SSHNPNoOpSuccess', () {
      test('SSHNPNoOpSuccess.toString() test', () {
        expect(SshnpNoOpSuccess().toString(), equals('Connection Established'));
      });
      test('SSHNPNoOpSuccess.connectionBean test', () {
        SshnpNoOpSuccess<String> success =
            SshnpNoOpSuccess(connectionBean: 'myBean');
        expect(success.connectionBean, equals('myBean'));
      });
    }); // group('SSHNPNoOpSuccess')
  });
  group('SSHNPConnectionBean', () {
    test('SSHNPConnectionBean<Process>.killConnectionBean() test', () {
      final bean = SshnpConnectionBean<Process>();
      final process = MockProcess();
      when(() => process.kill()).thenReturn(true);
      bean.connectionBean = process;

      verifyNever(() => process.kill());
      expect(bean.killConnectionBean(), completes);
      verify(() => process.kill()).called(1);
    });

    test('SSHNPConnectionBean<Future<Process>>.killConnectionBean() test',
        () async {
      final bean = SshnpConnectionBean<Future<Process>>();
      final process = MockProcess();
      when(() => process.kill()).thenReturn(true);
      final fProcess = Future.value(process);
      bean.connectionBean = fProcess;

      verifyNever(() => process.kill());
      await expectLater(bean.killConnectionBean(), completes);
      verify(() => process.kill()).called(1);
    });
    test('SSHNPConnectionBean<SocketConnector>.killConnectionBean() test', () {
      final bean = SshnpConnectionBean<SocketConnector>();
      final socketConnector = MockSocketConnector();
      when(() => socketConnector.close()).thenReturn(null);
      bean.connectionBean = socketConnector;

      verifyNever(() => socketConnector.close());
      expect(bean.killConnectionBean(), completes);
      verify(() => socketConnector.close()).called(1);
    });
    test(
        'SSHNPConnectionBean<Future<SocketConnector>>.killConnectionBean() test',
        () async {
      final bean = SshnpConnectionBean<Future<SocketConnector>>();
      final socketConnector = MockSocketConnector();
      final fSocketConnector = Future.value(socketConnector);
      when(() => socketConnector.close()).thenReturn(null);
      bean.connectionBean = fSocketConnector;

      verifyNever(() => socketConnector.close());
      expect(bean.connectionBean, completes);
      await expectLater(bean.killConnectionBean(), completes);
      verify(() => socketConnector.close()).called(1);
    });
  }); // group('SSHNPConnectionBean')
}
