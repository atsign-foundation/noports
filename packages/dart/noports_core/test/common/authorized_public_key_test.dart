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
          'AAAACw==',
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

    test(
      'refuses key data whose length is not a multiple of 4, with more than two "=", or with padding bits set',
      () {
        final String paddingBitsSet = '${e1.substring(0, e1.length - 2)}d=';
        expect(e1, endsWith('c='));
        for (final String keyData in [
          k1.substring(0, 66),
          '${k1.substring(0, 65)}===',
          paddingBitsSet,
          'AAAACx==',
        ]) {
          expect(
            () => AuthorizedPublicKey.parse('ecdsa-sha2-nistp256 $keyData'),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                'its key data is not of its stated key type',
              ),
            ),
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

    test(
      'leaves out a longer comment, or one holding a character outside ASCII',
      () {
        for (final String comment in ['x' * 257, 'caf\u00e9', '\u00a0x']) {
          final key = AuthorizedPublicKey.parse('ssh-ed25519 $k1 $comment');
          expect(key.comment, isNull, reason: comment);
          expect(key.commentLeftOut, isTrue, reason: comment);
          expect(key.line(), '${loopbackLine('ssh-ed25519', k1)}\n');
        }
      },
    );

    test('refuses a value over 8192 bytes counted in UTF-8', () {
      final String value = 'ssh-ed25519 $k1 '.padRight(8190, 'a');
      expect(AuthorizedPublicKey.parse('$valueé').commentLeftOut, isTrue);
      expect(() => AuthorizedPublicKey.parse('$value€'), throwsFormatException);
    });
  });

  group('AuthorizedPublicKey.line', () {
    test('refuses permissions holding a CR, an LF or a from option', () {
      final key = AuthorizedPublicKey.parse('ssh-ed25519 $k1');
      for (final String permissions in [
        'no-pty\nssh-ed25519 $k2',
        'no-pty\r',
        'from="10.0.0.0/8"',
        'no-pty,FROM="10.0.0.0/8"',
      ]) {
        expect(
          () => key.line(permissions: permissions),
          throwsArgumentError,
          reason: permissions,
        );
      }
      expect(
        key.line(permissions: 'no-pty'),
        '${loopbackLine('ssh-ed25519', k1, permissions: 'no-pty')}\n',
      );
    });

    test('trims each permission and leaves empty ones out', () {
      final key = AuthorizedPublicKey.parse('ssh-ed25519 $k1');
      for (final String permissions in [' no-pty', 'no-pty,,']) {
        expect(
          key.line(permissions: permissions),
          '${loopbackLine('ssh-ed25519', k1, permissions: 'no-pty')}\n',
          reason: permissions,
        );
      }
    });
  });

  group('sshKeyPermissionsLeavingOutFrom', () {
    test(
      'leaves out a from option in any case, wherever it is in the list',
      () {
        for (final MapEntry(key: permissions, value: kept) in {
          'from="10.0.0.0/8"': '',
          'FROM="10.0.0.0/8"': '',
          'no-pty,From="10.0.0.0/8"': 'no-pty',
          'command="echo a,b",from="10.0.0.0/8",no-pty':
              'command="echo a,b",no-pty',
          'no-pty, from="10.0.0.0/8"': 'no-pty',
          'no-pty,from': 'no-pty',
        }.entries) {
          expect(sshKeyPermissionsLeavingOutFrom(permissions), (
            permissions: kept,
            fromLeftOut: true,
          ), reason: permissions);
        }
      },
    );

    test('keeps every option that is not from, dropping empty ones', () {
      for (final MapEntry(key: permissions, value: kept) in {
        '': '',
        'no-pty': 'no-pty',
        'no-port-forwarding,,no-pty,': 'no-port-forwarding,no-pty',
        'command="echo a,from=b"': 'command="echo a,from=b"',
        'command="echo \\",from=b"': 'command="echo \\",from=b"',
        'environment="FROM=x"': 'environment="FROM=x"',
        'fromage': 'fromage',
      }.entries) {
        expect(sshKeyPermissionsLeavingOutFrom(permissions), (
          permissions: kept,
          fromLeftOut: false,
        ), reason: permissions);
      }
    });
  });

  group('authorizedKeysLineKey', () {
    test('reads the key data after a supported key type, past any options', () {
      for (final MapEntry(key: line, value: keyData) in {
        'ssh-ed25519 $k1': k1,
        'ssh-ed25519 $k1 user@laptop': k1,
        ' \tssh-ed25519 $k1': k1,
        'no-pty ssh-ed25519 $k1': k1,
        'command="echo a b",no-pty ssh-rsa $r1 me': r1,
        'command="echo \\" ssh-ed25519 $k0" ssh-ed25519 $k1': k1,
        'ssh-ed25519 $k0 $k1': k0,
        'ssh-ed25519 $k0 ssh-ed25519 $k1': k0,
        'ssh-ed25519 ${k1}x': '${k1}x',
      }.entries) {
        expect(authorizedKeysLineKey(line)?.keyData, keyData, reason: line);
      }
    });

    test('finds no key on a blank line, a # line, or an unsupported type', () {
      for (final String line in [
        '',
        '  ',
        '# ssh-ed25519 $k1',
        ' \t#ssh-ed25519 $k1',
        'ssh-dss $k1',
        'no-pty ssh-dss $k1',
        'no-pty',
      ]) {
        expect(authorizedKeysLineKey(line), isNull, reason: line);
      }
    });

    test('says whether the line allows logins only from loopback', () {
      for (final MapEntry(key: options, value: loopbackOnly) in {
        'from="127.0.0.1,::1"': true,
        'from="127.0.0.1,::1",no-pty': true,
        'no-pty,FROM="127.0.0.1,::1"': true,
        'from="10.0.0.0/8"': false,
        'no-pty': false,
        'command="from=\\"127.0.0.1,::1\\""': false,
      }.entries) {
        expect(
          authorizedKeysLineKey('$options ssh-ed25519 $k1')?.loopbackOnly,
          loopbackOnly,
          reason: options,
        );
      }
      expect(authorizedKeysLineKey('ssh-ed25519 $k1')?.loopbackOnly, isFalse);
    });
  });

  group('oneLineForLog', () {
    test(
      'escapes each byte outside printable ASCII, and each quote and backslash',
      () {
        expect(
          oneLineForLog(
            'a\nb\rc\td\x00e\x7ff\u0085g\u2028h"i\\j caf\u00e9 \u{1f600}',
          ),
          r'a\nb\rc\td\x00e\x7ff\xc2\x85g\xe2\x80\xa8h\"i\\j caf\xc3\xa9 '
          r'\xf0\x9f\x98\x80',
        );
      },
    );

    test('cuts to 200 characters without splitting an escape', () {
      expect(oneLineForLog('x' * 300), 'x' * 200);
      expect(oneLineForLog('${'x' * 199}\n'), 'x' * 199);
      expect(oneLineForLog('${'x' * 198}\n'), '${'x' * 198}\\n');
      expect(oneLineForLog('${'x' * 197}\u00e9'), 'x' * 197);
      expect(oneLineForLog('${'x' * 196}\u00e9'), '${'x' * 196}\\xc3');
    });
  });
}
