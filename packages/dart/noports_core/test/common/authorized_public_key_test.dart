import 'dart:convert';
import 'dart:typed_data';

import 'package:noports_core/src/common/at_ssh_key_util/authorized_public_key.dart';
import 'package:test/test.dart';

import 'ssh_public_key_fixtures.dart';

/// Key data whose first field names [type], followed by some key bytes.
String keyDataNaming(String type) {
  final List<int> name = ascii.encode(type);
  final ByteData length = ByteData(4)..setUint32(0, name.length);
  return base64.encode([
    ...length.buffer.asUint8List(),
    ...name,
    ...List.filled(32, 7),
  ]);
}

void main() {
  group('AuthorizedPublicKey.parse', () {
    test('accepts each supported key type whose key data names it', () {
      for (final MapEntry(key: type, value: dataType)
          in AuthorizedPublicKey.keyDataTypes.entries) {
        final key = AuthorizedPublicKey.parse(
          '$type ${keyDataNaming(dataType)}',
        );
        expect(key.type, dataType, reason: type);
      }
      expect(
        AuthorizedPublicKey.parse('ecdsa-sha2-nistp256 $e1').type,
        'ecdsa-sha2-nistp256',
      );
      expect(AuthorizedPublicKey.parse('ssh-rsa $r1').type, 'ssh-rsa');
      expect(AuthorizedPublicKey.parse('rsa-sha2-512 $r1').type, 'ssh-rsa');
    });

    test('refuses key data that names another type', () {
      for (final String value in [
        'ssh-ed25519 $r1',
        'ssh-rsa $k1',
        'rsa-sha2-256 $k1',
        'ecdsa-sha2-nistp384 $e1',
        'ssh-ed25519 ${keyDataNaming('ssh-ed25519x')}',
        'ssh-ed25519 ${keyDataNaming('ssh-ed2551')}',
      ]) {
        expect(
          () => AuthorizedPublicKey.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('refuses a key type outside the list whose key data names it', () {
      for (final String type in [
        'ssh-dss',
        'sk-ssh-ed25519@openssh.com',
        'ssh-ed25519-cert-v01@openssh.com',
      ]) {
        expect(
          () => AuthorizedPublicKey.parse('$type ${keyDataNaming(type)}'),
          throwsFormatException,
          reason: type,
        );
      }
    });

    test(
      'refuses key data that is not base64, or too short to name a type',
      () {
        for (final String keyData in [
          '${k1.substring(0, 67)}!',
          k1.substring(0, 67),
          k1.replaceAll('+', '-'),
          'AAAA',
          'AAAAC3Nz',
          '=AAA',
        ]) {
          expect(
            () => AuthorizedPublicKey.parse('ssh-ed25519 $keyData'),
            throwsFormatException,
            reason: keyData,
          );
        }
      },
    );

    test('refuses a value that is not a type then key data', () {
      for (final String value in [
        '',
        'ssh-ed25519',
        k1,
        'ssh-ed25519  $k1',
        'SSH-ED25519 $k1',
      ]) {
        expect(
          () => AuthorizedPublicKey.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('trims surrounding whitespace', () {
      final key = AuthorizedPublicKey.parse(' \t\r\nssh-ed25519 $k1 me\r\n ');
      expect(key.line(), '${loopbackLine('ssh-ed25519', k1, comment: 'me')}\n');
    });

    test(
      'refuses a value holding a control character, U+0085, U+2028 or U+2029',
      () {
        for (final String c in [
          '\n',
          '\r',
          '\t',
          '\x00',
          '\x1b',
          '\x7f',
          '\u0085',
          '\u2028',
          '\u2029',
        ]) {
          expect(
            () => AuthorizedPublicKey.parse('ssh-ed25519 $k1 a${c}b'),
            throwsFormatException,
            reason: jsonEncode(c),
          );
        }
      },
    );

    test('keeps a printable ASCII comment of up to 256 characters', () {
      final String comment = ' !~${'x' * 253}';
      final key = AuthorizedPublicKey.parse('ssh-ed25519 $k1 $comment');
      expect(key.comment, comment);
      expect(key.commentLeftOut, isFalse);
    });

    test('leaves out a longer comment, or one not printable ASCII', () {
      for (final String comment in ['x' * 257, 'café', ' x']) {
        final key = AuthorizedPublicKey.parse('ssh-ed25519 $k1 $comment');
        expect(key.comment, isNull, reason: comment);
        expect(key.commentLeftOut, isTrue, reason: comment);
        expect(key.line(), '${loopbackLine('ssh-ed25519', k1)}\n');
      }
    });

    test('refuses a value over 8192 bytes counted in UTF-8', () {
      final String value = 'ssh-ed25519 $k1 '.padRight(8190, 'a');
      expect(AuthorizedPublicKey.parse('$valueé').commentLeftOut, isTrue);
      expect(() => AuthorizedPublicKey.parse('$value€'), throwsFormatException);
    });
  });

  group('sshKeyPermissionsHoldFrom', () {
    test('finds a from option in any case, wherever it is in the list', () {
      for (final String permissions in [
        'from="10.0.0.0/8"',
        'FROM="10.0.0.0/8"',
        'no-pty,From="10.0.0.0/8"',
        'command="echo a,b",from="10.0.0.0/8"',
        'no-pty, from="10.0.0.0/8"',
        'no-pty,from',
      ]) {
        expect(
          sshKeyPermissionsHoldFrom(permissions),
          isTrue,
          reason: permissions,
        );
      }
    });

    test('does not count from= inside a quoted value', () {
      for (final String permissions in [
        '',
        'no-pty',
        'no-port-forwarding,no-pty',
        'command="echo a,from=b"',
        'command="echo \\",from=b"',
        'environment="FROM=x"',
        'fromage',
      ]) {
        expect(
          sshKeyPermissionsHoldFrom(permissions),
          isFalse,
          reason: permissions,
        );
      }
    });
  });

  group('oneLineForLog', () {
    test('escapes control characters and line separators', () {
      expect(
        oneLineForLog('a\nb\rc\td\x00e\x7ff\u0085g\u2028h\u2029i'),
        r'a\nb\rc\td\x00e\x7ff\x85g\u2028h\u2029i',
      );
    });

    test('cuts to 200 characters without splitting an escape', () {
      expect(oneLineForLog('x' * 300), 'x' * 200);
      expect(oneLineForLog('${'x' * 199}\n'), 'x' * 199);
      expect(oneLineForLog('${'x' * 198}\n'), '${'x' * 198}\\n');
    });
  });
}
