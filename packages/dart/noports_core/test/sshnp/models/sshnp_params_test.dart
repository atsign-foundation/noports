import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

void main() {
  group('NptParams', () {
    test('malformed client atSign missing prefix', () {
      expect(
          () => NptParams(
                clientAtSign: '',
                sshnpdAtSign: '@daemon',
                srvdAtSign: '@relay',
                device: 'foo',
                inline: false,
                remoteHost: 'localhost',
                remotePort: 3389,
                timeout: DefaultArgs.srvTimeout,
              ),
          throwsA(TypeMatcher<ArgumentError>()));
    });
    test('malformed daemon atSign missing prefix', () {
      expect(
          () => NptParams(
                clientAtSign: '@client',
                sshnpdAtSign: '',
                srvdAtSign: '@relay',
                device: 'foo',
                inline: false,
                remoteHost: 'localhost',
                remotePort: 3389,
                timeout: DefaultArgs.srvTimeout,
              ),
          throwsA(TypeMatcher<ArgumentError>()));
    });
    test('malformed relay atSign missing prefix', () {
      expect(
          () => NptParams(
                clientAtSign: '@client',
                sshnpdAtSign: '@daemon',
                srvdAtSign: '',
                device: 'foo',
                inline: false,
                remoteHost: 'localhost',
                remotePort: 3389,
                timeout: DefaultArgs.srvTimeout,
              ),
          throwsA(TypeMatcher<ArgumentError>()));
    });
  });
  group('SshnpParams', () {
    test('public API test', () {
      final params =
          SshnpParams(clientAtSign: '', sshnpdAtSign: '', srvdAtSign: '');
      expect(params, isNotNull);
      expect(params.clientAtSign, isA<String>());
      expect(params.sshnpdAtSign, isA<String>());
      expect(params.srvdAtSign, isA<String>());
      expect(params.device, isA<String>());
      expect(params.localPort, isA<int>());
      expect(params.identityFile, isA<String?>());
      expect(params.identityPassphrase, isA<String?>());
      expect(params.sendSshPublicKey, isA<bool>());
      expect(params.localSshOptions, isA<List<String>>());
      expect(params.remoteUsername, isA<String?>());
      expect(params.tunnelUsername, isA<String?>());
      expect(params.verbose, isA<bool>());
      expect(params.rootDomain, isA<String>());
      expect(params.remoteSshdPort, isA<int>());
      expect(params.idleTimeout, isA<int>());
      expect(params.addForwardsToTunnel, isA<bool>());
      expect(params.atKeysFilePath, isA<String?>());
      expect(params.profileName, isA<String?>());
      expect(params.listDevices, isA<bool>());
      expect(params.toConfigLines(), isA<List<String>>());
      expect(params.toArgMap(), isA<Map<String, dynamic>>());
      expect(params.toJson(), isA<String>());
    });

    group('SshnpParams final variables', () {
      test('SshnpParams.clientAtSign test', () {
        final params = SshnpParams(
            clientAtSign: '@myClientAtSign', sshnpdAtSign: '', srvdAtSign: '');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SshnpParams.sshnpdAtSign test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '@mySshnpdAtSign', srvdAtSign: '');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SshnpParams.host test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', srvdAtSign: '@my_srvd');
        expect(params.srvdAtSign, equals('@my_srvd'));
      });
      test('SshnpParams.device invalid with uppercase test', () {
        expect(
            () => SshnpParams(
                clientAtSign: '',
                sshnpdAtSign: '',
                srvdAtSign: '',
                device: 'myDeviceName'),
            throwsA(TypeMatcher<ArgumentError>()));
      });
      test('SshnpParams.device invalid with disallowed chars test', () {
        expect(
            () => SshnpParams(
                clientAtSign: '',
                sshnpdAtSign: '',
                srvdAtSign: '',
                device: 'my-device-name'),
            throwsA(TypeMatcher<ArgumentError>()));
      });
      test('SshnpParams.device invalid too long test', () {
        expect(
            () => SshnpParams(
                clientAtSign: '',
                sshnpdAtSign: '',
                srvdAtSign: '',
                device: 'abcde_12345_abcde_12345_abcde_12345_X'),
            throwsA(TypeMatcher<ArgumentError>()));
      });
      test('SshnpParams.device test', () {
        String deviceName = 'my_device_name_12345';
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            device: deviceName);
        expect(params.device, equals(deviceName));
      });
      test('SshnpParams.localPort test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SshnpParams.identityFile test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SshnpParams.identityPassphrase test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SshnpParams.sendSshPublicKey test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SshnpParams.localSshOptions test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SshnpParams.remoteUsername test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SshnpParams.tunnelUsername test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            tunnelUsername: 'myTunnelUsername');
        expect(params.tunnelUsername, equals('myTunnelUsername'));
      });
      test('SshnpParams.verbose test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', srvdAtSign: '', verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SshnpParams.rootDomain test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SshnpParams.remoteSshdPort test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SshnpParams.idleTimeout test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SshnpParams.addForwardsToTunnel test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SshnpParams.atKeysFilePath test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SshnpParams.profileName test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SshnpParams.listDevices test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            srvdAtSign: '',
            listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SshnpParams final variables')

    group('SshnpParams factories', () {
      test('SshnpParams.empty() test', () {
        final params = SshnpParams.empty();
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.srvdAtSign, equals(''));
        expect(params.device, equals(DefaultSshnpArgs.device));
        expect(params.localPort, equals(DefaultSshnpArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSshnpArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSshnpArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.tunnelUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.listDevices, equals(DefaultSshnpArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
      });
      test('SshnpParams.merge() test (overrides take priority)', () {
        final params = SshnpParams.merge(
          SshnpParams.empty(),
          SshnpPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            srvdAtSign: '@mySrvdAtSign',
            device: 'my_device_name_12345',
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            tunnelUsername: 'myTunnelUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshAlgorithm: SupportedSshAlgorithm.rsa,
          ),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SshnpParams.merge() test (null coalesce values)', () {
        final params =
            SshnpParams.merge(SshnpParams.empty(), SshnpPartialParams());
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.srvdAtSign, equals(''));
        expect(params.device, equals(DefaultSshnpArgs.device));
        expect(params.localPort, equals(DefaultSshnpArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSshnpArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSshnpArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.tunnelUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.listDevices, equals(DefaultSshnpArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
      });
      test('SshnpParams.fromJson() test', () {
        String json = '{'
            '"${SshnpArg.profileNameArg.name}": "myProfile",'
            '"${SshnpArg.fromArg.name}": "@myClientAtSign",'
            '"${SshnpArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SshnpArg.srvdArg.name}": "@mySrvdAtSign",'
            '"${SshnpArg.deviceArg.name}": "my_device_name_12345",'
            '"${SshnpArg.localPortArg.name}": 2345,'
            '"${SshnpArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SshnpArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SshnpArg.sendSshPublicKeyArg.name}": true,'
            '"${SshnpArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SshnpArg.remoteUserNameArg.name}": "myUsername",'
            '"${SshnpArg.tunnelUserNameArg.name}": "myTunnelUsername",'
            '"${SshnpArg.verboseArg.name}": true,'
            '"${SshnpArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SshnpArg.remoteSshdPortArg.name}": 2222,'
            '"${SshnpArg.idleTimeoutArg.name}": 120,'
            '"${SshnpArg.addForwardsToTunnelArg.name}": true,'
            '"${SshnpArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SshnpArg.sshAlgorithmArg.name}": "${SupportedSshAlgorithm.rsa.toString()}"'
            '}';

        final params = SshnpParams.fromJson(json);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SshnpParams.fromPartial() test', () {
        final partial = SshnpPartialParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          srvdAtSign: '@mySrvdAtSign',
        );
        final params = SshnpParams.fromPartial(partial);
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
      });
      test('SshnpParams.fromConfigLines() test', () {
        final configLines = [
          '${SshnpArg.fromArg.bashName} = @myClientAtSign',
          '${SshnpArg.toArg.bashName} = @mySshnpdAtSign',
          '${SshnpArg.srvdArg.bashName} = @mySrvdAtSign',
          '${SshnpArg.deviceArg.bashName} = my_device_name_12345',
          '${SshnpArg.localPortArg.bashName} = 2345',
          '${SshnpArg.identityFileArg.bashName} = .ssh/id_ed25519',
          '${SshnpArg.identityPassphraseArg.bashName} = myPassphrase',
          '${SshnpArg.sendSshPublicKeyArg.bashName} = true',
          '${SshnpArg.localSshOptionsArg.bashName} = -L 127.0.01:8080:127.0.0.1:80',
          '${SshnpArg.remoteUserNameArg.bashName} = myUsername',
          '${SshnpArg.tunnelUserNameArg.bashName} = myTunnelUsername',
          '${SshnpArg.rootDomainArg.bashName} = root.atsign.wtf',
          '${SshnpArg.remoteSshdPortArg.bashName} = 2222',
          '${SshnpArg.idleTimeoutArg.bashName} = 120',
          '${SshnpArg.addForwardsToTunnelArg.bashName} = true',
          '${SshnpArg.keyFileArg.bashName} = ~/.atsign/@myAtsign_keys.atKeys',
          '${SshnpArg.sshAlgorithmArg.bashName} = ${SupportedSshAlgorithm.rsa.toString()}',
          '${SshnpArg.authenticateClientToRvdArg.bashName} = false',
          '${SshnpArg.authenticateDeviceToRvdArg.bashName} = false',
          '${SshnpArg.encryptRvdTrafficArg.bashName} = false',
        ];
        final params = SshnpParams.fromConfigLines('myProfile', configLines);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.authenticateClientToRvd, equals(false));
        expect(params.authenticateDeviceToRvd, equals(false));
        expect(params.encryptRvdTraffic, equals(false));
      });
    }); // group('SshnpParams factories')
    group('SshnpParams functions', () {
      test('SshnpParams.toConfigLines', () {
        final params = SshnpParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          srvdAtSign: '@mySrvdAtSign',
          device: 'my_device_name_12345',
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          tunnelUsername: 'myTunnelUsername',
          rootDomain: 'root.atsign.wtf',
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          authenticateClientToRvd: false,
          authenticateDeviceToRvd: false,
          encryptRvdTraffic: false,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SshnpParams.fromConfigLines('myProfile', configLines);
        expect(parsedParams.profileName, equals('myProfile'));
        expect(
            parsedParams.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(
            parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(parsedParams.srvdAtSign, equals('@mySrvdAtSign'));
        expect(parsedParams.device, equals('my_device_name_12345'));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.tunnelUsername, equals('myTunnelUsername'));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.remoteSshdPort, equals(2222));
        expect(parsedParams.authenticateClientToRvd, false);
        expect(parsedParams.authenticateDeviceToRvd, false);
        expect(parsedParams.encryptRvdTraffic, false);
      });
      test('SshnpParams.toArgMap', () {
        final params = SshnpParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          srvdAtSign: '@mySrvdAtSign',
          device: 'my_device_name_12345',
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          tunnelUsername: 'myTunnelUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
        );
        final argMap = params.toArgMap();
        expect(argMap[SshnpArg.fromArg.name], equals('@myClientAtSign'));
        expect(argMap[SshnpArg.toArg.name], equals('@mySshnpdAtSign'));
        expect(argMap[SshnpArg.srvdArg.name], equals('@mySrvdAtSign'));
        expect(argMap[SshnpArg.deviceArg.name], equals('my_device_name_12345'));
        expect(argMap[SshnpArg.localPortArg.name], equals(2345));
        expect(
            argMap[SshnpArg.identityFileArg.name], equals('.ssh/id_ed25519'));
        expect(argMap[SshnpArg.identityPassphraseArg.name],
            equals('myPassphrase'));
        expect(argMap[SshnpArg.sendSshPublicKeyArg.name], equals(true));
        expect(argMap[SshnpArg.localSshOptionsArg.name],
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(argMap[SshnpArg.remoteUserNameArg.name], equals('myUsername'));
        expect(argMap[SshnpArg.tunnelUserNameArg.name],
            equals('myTunnelUsername'));
        expect(argMap[SshnpArg.verboseArg.name], equals(true));
        expect(argMap[SshnpArg.rootDomainArg.name], equals('root.atsign.wtf'));
        expect(argMap[SshnpArg.remoteSshdPortArg.name], equals(2222));
        expect(argMap[SshnpArg.idleTimeoutArg.name], equals(120));
        expect(argMap[SshnpArg.addForwardsToTunnelArg.name], equals(true));
        expect(argMap[SshnpArg.keyFileArg.name],
            equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SshnpParams.toJson', () {
        final params = SshnpParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          srvdAtSign: '@mySrvdAtSign',
          device: 'my_device_name_12345',
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          tunnelUsername: 'myTunnelUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
        );
        final json = params.toJson();
        final parsedParams = SshnpParams.fromJson(json);
        expect(
            parsedParams.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(
            parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(parsedParams.srvdAtSign, equals('@mySrvdAtSign'));
        expect(parsedParams.device, equals('my_device_name_12345'));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.identityFile, equals('.ssh/id_ed25519'));
        expect(parsedParams.identityPassphrase, equals('myPassphrase'));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.tunnelUsername, equals('myTunnelUsername'));
        expect(parsedParams.verbose, equals(true));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.remoteSshdPort, equals(2222));
        expect(parsedParams.idleTimeout, equals(120));
        expect(parsedParams.addForwardsToTunnel, equals(true));
        expect(parsedParams.atKeysFilePath,
            equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
    }); // group('SshnpParams functions')
  }); // group('SshnpParams')

  group('SshnpPartialParams', () {
    test('public API test', () {
      final partialParams = SshnpPartialParams();
      expect(partialParams, isNotNull);
      expect(partialParams.clientAtSign, isA<String?>());
      expect(partialParams.sshnpdAtSign, isA<String?>());
      expect(partialParams.srvdAtSign, isA<String?>());
      expect(partialParams.device, isA<String?>());
      expect(partialParams.localPort, isA<int?>());
      expect(partialParams.identityFile, isA<String?>());
      expect(partialParams.identityPassphrase, isA<String?>());
      expect(partialParams.sendSshPublicKey, isA<bool?>());
      expect(partialParams.localSshOptions, isA<List<String>?>());
      expect(partialParams.remoteUsername, isA<String?>());
      expect(partialParams.tunnelUsername, isA<String?>());
      expect(partialParams.verbose, isA<bool?>());
      expect(partialParams.rootDomain, isA<String?>());
      expect(partialParams.remoteSshdPort, isA<int?>());
      expect(partialParams.idleTimeout, isA<int?>());
      expect(partialParams.addForwardsToTunnel, isA<bool?>());
      expect(partialParams.atKeysFilePath, isA<String?>());
      expect(partialParams.sshAlgorithm, isA<SupportedSshAlgorithm?>());
      expect(partialParams.profileName, isA<String?>());
      expect(partialParams.listDevices, isA<bool?>());
    });

    group('SshnpPartialParams final variables', () {
      test('SshnpPartialParams.clientAtSign test', () {
        final params = SshnpPartialParams(clientAtSign: '@myClientAtSign');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SshnpPartialParams.sshnpdAtSign test', () {
        final params = SshnpPartialParams(sshnpdAtSign: '@mySshnpdAtSign');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SshnpPartialParams.host test', () {
        final params = SshnpPartialParams(srvdAtSign: '@mySrvdAtSign');
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
      });
      test('SshnpPartialParams.device test', () {
        final params = SshnpPartialParams(device: 'my_device_name_12345');
        expect(params.device, equals('my_device_name_12345'));
      });
      test('SshnpPartialParams.localPort test', () {
        final params = SshnpPartialParams(localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SshnpPartialParams.identityFile test', () {
        final params = SshnpPartialParams(identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SshnpPartialParams.identityPassphrase test', () {
        final params = SshnpPartialParams(identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SshnpPartialParams.sendSshPublicKey test', () {
        final params = SshnpPartialParams(sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SshnpPartialParams.localSshOptions test', () {
        final params = SshnpPartialParams(
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SshnpPartialParams.remoteUsername test', () {
        final params = SshnpPartialParams(remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SshnpPartialParams.tunnelUsername test', () {
        final params = SshnpPartialParams(tunnelUsername: 'myTunnelUsername');
        expect(params.tunnelUsername, equals('myTunnelUsername'));
      });
      test('SshnpPartialParams.verbose test', () {
        final params = SshnpPartialParams(verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SshnpPartialParams.rootDomain test', () {
        final params = SshnpPartialParams(rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SshnpPartialParams.remoteSshdPort test', () {
        final params = SshnpPartialParams(remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SshnpPartialParams.idleTimeout test', () {
        final params = SshnpPartialParams(idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SshnpPartialParams.addForwardsToTunnel test', () {
        final params = SshnpPartialParams(addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SshnpPartialParams.atKeysFilePath test', () {
        final params = SshnpPartialParams(
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SshnpPartialParams.sshAlgorithm test', () {
        final params =
            SshnpPartialParams(sshAlgorithm: SupportedSshAlgorithm.rsa);
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SshnpPartialParams.profileName test', () {
        final params = SshnpPartialParams(profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SshnpPartialParams.listDevices test', () {
        final params = SshnpPartialParams(listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SshnpPartialParams final variables')
    group('SshnpPartialParams factories', () {
      test('SshnpPartialParams.empty() test', () {
        final params = SshnpPartialParams.empty();
        expect(params.profileName, isNull);
        expect(params.clientAtSign, isNull);
        expect(params.sshnpdAtSign, isNull);
        expect(params.srvdAtSign, isNull);
        expect(params.device, isNull);
        expect(params.localPort, isNull);
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(params.sendSshPublicKey, isNull);
        expect(params.localSshOptions, isNull);
        expect(params.verbose, isNull);
        expect(params.remoteUsername, isNull);
        expect(params.tunnelUsername, isNull);
        expect(params.rootDomain, isNull);
        expect(params.remoteSshdPort, isNull);
        expect(params.idleTimeout, isNull);
        expect(params.addForwardsToTunnel, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.sshAlgorithm, isNull);
        expect(params.listDevices, isNull);
      });
      test('SshnpPartialParams.merge() test (overrides take priority)', () {
        final params = SshnpPartialParams.merge(
          SshnpPartialParams.empty(),
          SshnpPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            srvdAtSign: '@mySrvdAtSign',
            device: 'my_device_name_12345',
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            tunnelUsername: 'myTunnelUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshAlgorithm: SupportedSshAlgorithm.rsa,
          ),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SshnpPartialParams.merge() test (null coalesce values)', () {
        final params = SshnpPartialParams.merge(
          SshnpPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            srvdAtSign: '@mySrvdAtSign',
            device: 'my_device_name_12345',
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            tunnelUsername: 'myTunnelUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshAlgorithm: SupportedSshAlgorithm.rsa,
          ),
          SshnpPartialParams.empty(),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      // TODO write tests for SshnpPartialParams.fromFile()
      test('SshnpPartial.fromConfigLines() test', () {
        final params = SshnpParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          srvdAtSign: '@mySrvdAtSign',
          device: 'my_device_name_12345',
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          tunnelUsername: 'myTunnelUsername',
          rootDomain: 'root.atsign.wtf',
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          authenticateClientToRvd: false,
          authenticateDeviceToRvd: false,
          encryptRvdTraffic: false,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SshnpPartialParams.fromConfigLines('myProfile', configLines);
        expect(parsedParams.profileName, equals('myProfile'));
        expect(
            parsedParams.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(
            parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(parsedParams.srvdAtSign, equals('@mySrvdAtSign'));
        expect(parsedParams.device, equals('my_device_name_12345'));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.tunnelUsername, equals('myTunnelUsername'));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.remoteSshdPort, equals(2222));
        expect(parsedParams.authenticateClientToRvd, false);
        expect(parsedParams.authenticateDeviceToRvd, false);
        expect(parsedParams.encryptRvdTraffic, false);
      });
      test('SshnpPartialParams.fromJson() test', () {
        String json = '{'
            '"${SshnpArg.profileNameArg.name}": "myProfile",'
            '"${SshnpArg.fromArg.name}": "@myClientAtSign",'
            '"${SshnpArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SshnpArg.srvdArg.name}": "@mySrvdAtSign",'
            '"${SshnpArg.deviceArg.name}": "my_device_name_12345",'
            '"${SshnpArg.localPortArg.name}": 2345,'
            '"${SshnpArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SshnpArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SshnpArg.sendSshPublicKeyArg.name}": true,'
            '"${SshnpArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SshnpArg.remoteUserNameArg.name}": "myUsername",'
            '"${SshnpArg.tunnelUserNameArg.name}": "myTunnelUsername",'
            '"${SshnpArg.verboseArg.name}": true,'
            '"${SshnpArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SshnpArg.remoteSshdPortArg.name}": 2222,'
            '"${SshnpArg.idleTimeoutArg.name}": 120,'
            '"${SshnpArg.addForwardsToTunnelArg.name}": true,'
            '"${SshnpArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SshnpArg.sshAlgorithmArg.name}": "${SupportedSshAlgorithm.rsa.toString()}"'
            '}';

        final params = SshnpPartialParams.fromJson(json);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SshnpPartialParams.fromArgMap() test', () {
        final params = SshnpPartialParams.fromArgMap({
          SshnpArg.profileNameArg.name: 'myProfile',
          SshnpArg.fromArg.name: '@myClientAtSign',
          SshnpArg.toArg.name: '@mySshnpdAtSign',
          SshnpArg.srvdArg.name: '@mySrvdAtSign',
          SshnpArg.deviceArg.name: 'my_device_name_12345',
          SshnpArg.localPortArg.name: 2345,
          SshnpArg.identityFileArg.name: '.ssh/id_ed25519',
          SshnpArg.identityPassphraseArg.name: 'myPassphrase',
          SshnpArg.sendSshPublicKeyArg.name: true,
          SshnpArg.localSshOptionsArg.name: ['-L 127.0.01:8080:127.0.0.1:80'],
          SshnpArg.remoteUserNameArg.name: 'myUsername',
          SshnpArg.tunnelUserNameArg.name: 'myTunnelUsername',
          SshnpArg.verboseArg.name: true,
          SshnpArg.rootDomainArg.name: 'root.atsign.wtf',
          SshnpArg.remoteSshdPortArg.name: 2222,
          SshnpArg.idleTimeoutArg.name: 120,
          SshnpArg.addForwardsToTunnelArg.name: true,
          SshnpArg.keyFileArg.name: '~/.atsign/@myAtsign_keys.atKeys',
          SshnpArg.sshAlgorithmArg.name: SupportedSshAlgorithm.rsa.toString(),
        });
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SshnpPartialParams.fromArgList() test', () {
        final argList = [
          '--${SshnpArg.profileNameArg.name}',
          'myProfile',
          '--${SshnpArg.fromArg.name}',
          '@myClientAtSign',
          '--${SshnpArg.toArg.name}',
          '@mySshnpdAtSign',
          '--${SshnpArg.srvdArg.name}',
          '@mySrvdAtSign',
          '--${SshnpArg.deviceArg.name}',
          'my_device_name_12345',
          '--${SshnpArg.localPortArg.name}',
          '2345',
          '--${SshnpArg.identityFileArg.name}',
          '.ssh/id_ed25519',
          '--${SshnpArg.identityPassphraseArg.name}',
          'myPassphrase',
          '--${SshnpArg.sendSshPublicKeyArg.name}',
          '--${SshnpArg.localSshOptionsArg.name}',
          '-L 127.0.01:8080:127.0.0.1:80',
          '--${SshnpArg.remoteUserNameArg.name}',
          'myUsername',
          '--${SshnpArg.tunnelUserNameArg.name}',
          'myTunnelUsername',
          '--${SshnpArg.verboseArg.name}',
          '--${SshnpArg.rootDomainArg.name}',
          'root.atsign.wtf',
          '--${SshnpArg.remoteSshdPortArg.name}',
          '2222',
          '--${SshnpArg.idleTimeoutArg.name}',
          '120',
          '--${SshnpArg.addForwardsToTunnelArg.name}',
          '--${SshnpArg.keyFileArg.name}',
          '~/.atsign/@myAtsign_keys.atKeys',
          '--${SshnpArg.sshAlgorithmArg.name}',
          SupportedSshAlgorithm.rsa.toString(),
        ];
        final params = SshnpPartialParams.fromArgList(argList);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'.toLowerCase()));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'.toLowerCase()));
        expect(params.srvdAtSign, equals('@mySrvdAtSign'));
        expect(params.device, equals('my_device_name_12345'));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.tunnelUsername, equals('myTunnelUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
    }); // group('SshnpPartialParams factories')
  }); // group('SshnpPartialParams')
}
