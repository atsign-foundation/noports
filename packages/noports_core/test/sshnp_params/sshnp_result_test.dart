import 'package:noports_core/sshnp.dart';
import 'package:test/test.dart';

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
    });
    group('SSHNPCommand', () {
      test('toString() test', () {
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
    });
      });
}
