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
        expect(SSHNPSuccess(), isA<SSHNPResult>());
      });
      test('SSHNPCommand test', () {
        final res = SSHNPCommand(host: 'localhost', localPort: 22);
        expect(res, isA<SSHNPSuccess>());
      });
      test('SSHNPNoOpSuccess test', () {
        final res = SSHNPNoOpSuccess();
        expect(res, isA<SSHNPResult>());
        expect(res, isA<SSHNPSuccess>());
      });
      test('SSHNPFailure test', () {
        expect(SSHNPFailure(), isA<SSHNPResult>());
      });
      test('SSHNPError test', () {
        final res = SSHNPError('error message');
        expect(res, isA<SSHNPResult>());
        expect(res, isA<SSHNPFailure>());
      });
    }); // group('Subclass Confirmation')
    group('SSHNPError', () {
      late StackTrace stackTrace;
      late SSHNPError error;
      setUp(() {
        stackTrace = StackTrace.current;
        error =
            SSHNPError('myMessage', error: 'myError', stackTrace: stackTrace);
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
        final command = SSHNPCommand(
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
        SSHNPCommand<String> command = SSHNPCommand(
          host: 'localhost',
          localPort: 22,
          connectionBean: 'myBean',
        );
        expect(command.connectionBean, equals('myBean'));
      });
      test('static SSHNPCommand.shouldIncludePrivateKey test', () {
        expect(SSHNPCommand.shouldIncludePrivateKey(null), isFalse);
        expect(SSHNPCommand.shouldIncludePrivateKey(''), isFalse);
        // it is not the responsibility of this class to validate whether the private key file name is valid
        // it purely wants to know whether there is a value or not
        expect(SSHNPCommand.shouldIncludePrivateKey('asdfkjsdflkjd'), isTrue);
      });
      test('SSHNPCommand.args test', () {
        final command = SSHNPCommand(
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
        expect(SSHNPNoOpSuccess().toString(), equals('Connection Established'));
      });
      test('SSHNPNoOpSuccess.connectionBean test', () {
        SSHNPNoOpSuccess<String> success =
            SSHNPNoOpSuccess(connectionBean: 'myBean');
        expect(success.connectionBean, equals('myBean'));
      });
    }); // group('SSHNPNoOpSuccess')
  });
  group('SSHNPConnectionBean', () {
    test('SSHNPConnectionBean<Process>.killConnectionBean() test', () {
      final bean = SSHNPConnectionBean<Process>();
      final process = MockProcess();
      when(() => process.kill()).thenReturn(true);
      bean.connectionBean = process;

      verifyNever(() => process.kill());
      expect(bean.killConnectionBean(), completes);
      verify(() => process.kill()).called(1);
    });

    test('SSHNPConnectionBean<Future<Process>>.killConnectionBean() test',
        () async {
      final bean = SSHNPConnectionBean<Future<Process>>();
      final process = MockProcess();
      when(() => process.kill()).thenReturn(true);
      final fProcess = Future.value(process);
      bean.connectionBean = fProcess;

      verifyNever(() => process.kill());
      await expectLater(bean.killConnectionBean(), completes);
      verify(() => process.kill()).called(1);
    });
    test('SSHNPConnectionBean<SocketConnector>.killConnectionBean() test', () {
      final bean = SSHNPConnectionBean<SocketConnector>();
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
      final bean = SSHNPConnectionBean<Future<SocketConnector>>();
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
