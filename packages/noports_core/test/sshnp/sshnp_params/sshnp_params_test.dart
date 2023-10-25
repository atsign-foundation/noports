import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

void main() {
  group('SSHNPParams', () {
    test('public API test', () {
      final params = SSHNPParams(clientAtSign: '', sshnpdAtSign: '', host: '');
      expect(params, isNotNull);
      expect(params.clientAtSign, isA<String>());
      expect(params.sshnpdAtSign, isA<String>());
      expect(params.host, isA<String>());
      expect(params.device, isA<String>());
      expect(params.port, isA<int>());
      expect(params.localPort, isA<int>());
      expect(params.identityFile, isA<String?>());
      expect(params.identityPassphrase, isA<String?>());
      expect(params.sendSshPublicKey, isA<bool>());
      expect(params.localSshOptions, isA<List<String>>());
      expect(params.remoteUsername, isA<String?>());
      expect(params.verbose, isA<bool>());
      expect(params.rootDomain, isA<String>());
      expect(params.localSshdPort, isA<int>());
      expect(params.legacyDaemon, isA<bool>());
      expect(params.remoteSshdPort, isA<int>());
      expect(params.idleTimeout, isA<int>());
      expect(params.addForwardsToTunnel, isA<bool>());
      expect(params.atKeysFilePath, isA<String?>());
      expect(params.sshClient, isA<SupportedSshClient>());
      expect(params.sshAlgorithm, isA<SupportedSSHAlgorithm>());
      expect(params.profileName, isA<String?>());
      expect(params.listDevices, isA<bool>());
      expect(params.toConfigLines(), isA<List<String>>());
      expect(params.toArgMap(), isA<Map<String, dynamic>>());
      expect(params.toJson(), isA<String>());
    });

    group('SSHNPParams final variables', () {
      test('SSHNPParams.clientAtSign test', () {
        final params = SSHNPParams(
            clientAtSign: '@myClientAtSign', sshnpdAtSign: '', host: '');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SSHNPParams.sshnpdAtSign test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '@mySshnpdAtSign', host: '');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SSHNPParams.host test', () {
        final params =
            SSHNPParams(clientAtSign: '', sshnpdAtSign: '', host: '@myHost');
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPParams.device test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            device: 'myDeviceName');
        expect(params.device, equals('myDeviceName'));
      });
      test('SSHNPParams.port test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', port: 1234);
        expect(params.port, equals(1234));
      });
      test('SSHNPParams.localPort test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SSHNPParams.identityFile test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SSHNPParams.identityPassphrase test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SSHNPParams.sendSshPublicKey test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SSHNPParams.localSshOptions test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SSHNPParams.remoteUsername test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SSHNPParams.verbose test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SSHNPParams.rootDomain test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SSHNPParams.localSshdPort test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', localSshdPort: 4567);
        expect(params.localSshdPort, equals(4567));
      });
      test('SSHNPParams.legacyDaemon test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', legacyDaemon: true);
        expect(params.legacyDaemon, equals(true));
      });
      test('SSHNPParams.remoteSshdPort test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SSHNPParams.idleTimeout test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SSHNPParams.addForwardsToTunnel test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SSHNPParams.atKeysFilePath test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SSHNPParams.sshClient test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sshClient: SupportedSshClient.dart);
        expect(params.sshClient, equals(SupportedSshClient.dart));
      });
      test('SSHNPParams.sshAlgorithm test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sshAlgorithm: SupportedSSHAlgorithm.rsa);
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPParams.profileName test', () {
        final params = SSHNPParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SSHNPParams.listDevices test', () {
        final params = SSHNPParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SSHNPParams final variables')

    group('SSHNPParams factories', () {
      test('SSHNPParams.empty() test', () {
        final params = SSHNPParams.empty();
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.host, equals(''));
        expect(params.device, equals(DefaultSSHNPArgs.device));
        expect(params.port, equals(DefaultSSHNPArgs.port));
        expect(params.localPort, equals(DefaultSSHNPArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSSHNPArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSSHNPArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.localSshdPort, equals(DefaultArgs.localSshdPort));
        expect(params.legacyDaemon, equals(DefaultSSHNPArgs.legacyDaemon));
        expect(params.listDevices, equals(DefaultSSHNPArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
        expect(params.sshClient, equals(DefaultSSHNPArgs.sshClient));
        expect(params.sshAlgorithm, equals(DefaultArgs.sshAlgorithm));
      });
      test('SSHNPParams.merge() test (overrides take priority)', () {
        final params = SSHNPParams.merge(
          SSHNPParams.empty(),
          SSHNPPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            host: '@myHost',
            device: 'myDeviceName',
            port: 1234,
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            localSshdPort: 4567,
            legacyDaemon: true,
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshClient: SupportedSshClient.dart,
            sshAlgorithm: SupportedSSHAlgorithm.rsa,
          ),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPParams.merge() test (null coalesce values)', () {
        final params =
            SSHNPParams.merge(SSHNPParams.empty(), SSHNPPartialParams());
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.host, equals(''));
        expect(params.device, equals(DefaultSSHNPArgs.device));
        expect(params.port, equals(DefaultSSHNPArgs.port));
        expect(params.localPort, equals(DefaultSSHNPArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSSHNPArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSSHNPArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.localSshdPort, equals(DefaultArgs.localSshdPort));
        expect(params.legacyDaemon, equals(DefaultSSHNPArgs.legacyDaemon));
        expect(params.listDevices, equals(DefaultSSHNPArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
        expect(params.sshClient, equals(DefaultSSHNPArgs.sshClient));
        expect(params.sshAlgorithm, equals(DefaultArgs.sshAlgorithm));
      });
      test('SSHNPParams.fromJson() test', () {
        String json = '{'
            '"${SSHNPArg.profileNameArg.name}": "myProfile",'
            '"${SSHNPArg.fromArg.name}": "@myClientAtSign",'
            '"${SSHNPArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SSHNPArg.hostArg.name}": "@myHost",'
            '"${SSHNPArg.deviceArg.name}": "myDeviceName",'
            '"${SSHNPArg.portArg.name}": 1234,'
            '"${SSHNPArg.localPortArg.name}": 2345,'
            '"${SSHNPArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SSHNPArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SSHNPArg.sendSshPublicKeyArg.name}": true,'
            '"${SSHNPArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SSHNPArg.remoteUserNameArg.name}": "myUsername",'
            '"${SSHNPArg.verboseArg.name}": true,'
            '"${SSHNPArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SSHNPArg.localSshdPortArg.name}": 4567,'
            '"${SSHNPArg.legacyDaemonArg.name}": true,'
            '"${SSHNPArg.remoteSshdPortArg.name}": 2222,'
            '"${SSHNPArg.idleTimeoutArg.name}": 120,'
            '"${SSHNPArg.addForwardsToTunnelArg.name}": true,'
            '"${SSHNPArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SSHNPArg.sshClientArg.name}": "${SupportedSshClient.dart.toString()}",'
            '"${SSHNPArg.sshAlgorithmArg.name}": "${SupportedSSHAlgorithm.rsa.toString()}"'
            '}';

        final params = SSHNPParams.fromJson(json);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPParams.fromPartial() test', () {
        final partial = SSHNPPartialParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
        );
        final params = SSHNPParams.fromPartial(partial);
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPParams.fromConfigLines() test', () {
        final configLines = [
          '${SSHNPArg.fromArg.bashName} = @myClientAtSign',
          '${SSHNPArg.toArg.bashName} = @mySshnpdAtSign',
          '${SSHNPArg.hostArg.bashName} = @myHost',
          '${SSHNPArg.deviceArg.bashName} = myDeviceName',
          '${SSHNPArg.portArg.bashName} = 1234',
          '${SSHNPArg.localPortArg.bashName} = 2345',
          '${SSHNPArg.identityFileArg.bashName} = .ssh/id_ed25519',
          '${SSHNPArg.identityPassphraseArg.bashName} = myPassphrase',
          '${SSHNPArg.sendSshPublicKeyArg.bashName} = true',
          '${SSHNPArg.localSshOptionsArg.bashName} = -L 127.0.01:8080:127.0.0.1:80',
          '${SSHNPArg.remoteUserNameArg.bashName} = myUsername',
          '${SSHNPArg.verboseArg.bashName} = true',
          '${SSHNPArg.rootDomainArg.bashName} = root.atsign.wtf',
          '${SSHNPArg.localSshdPortArg.bashName} = 4567',
          '${SSHNPArg.legacyDaemonArg.bashName} = true',
          '${SSHNPArg.remoteSshdPortArg.bashName} = 2222',
          '${SSHNPArg.idleTimeoutArg.bashName} = 120',
          '${SSHNPArg.addForwardsToTunnelArg.bashName} = true',
          '${SSHNPArg.keyFileArg.bashName} = ~/.atsign/@myAtsign_keys.atKeys',
          '${SSHNPArg.sshClientArg.bashName} = ${SupportedSshClient.dart.toString()}',
          '${SSHNPArg.sshAlgorithmArg.bashName} = ${SupportedSSHAlgorithm.rsa.toString()}',
        ];
        final params = SSHNPParams.fromConfigLines('myProfile', configLines);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
      });
    }); // group('SSHNPParams factories')
    group('SSHNPParams functions', () {
      test('SSHNPParams.toConfigLines', () {
        final params = SSHNPParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
          device: 'myDeviceName',
          port: 1234,
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          localSshdPort: 4567,
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          sshClient: SupportedSshClient.dart,
          sshAlgorithm: SupportedSSHAlgorithm.rsa,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SSHNPParams.fromConfigLines('myProfile', configLines);
        expect(parsedParams.profileName, equals('myProfile'));
        expect(parsedParams.clientAtSign, equals('@myClientAtSign'));
        expect(parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(parsedParams.host, equals('@myHost'));
        expect(parsedParams.device, equals('myDeviceName'));
        expect(parsedParams.port, equals(1234));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.verbose, equals(true));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.localSshdPort, equals(4567));
        expect(parsedParams.remoteSshdPort, equals(2222));
      });
      test('SSHNPParams.toArgMap', () {
        final params = SSHNPParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
          device: 'myDeviceName',
          port: 1234,
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          localSshdPort: 4567,
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          sshClient: SupportedSshClient.dart,
          sshAlgorithm: SupportedSSHAlgorithm.rsa,
        );
        final argMap = params.toArgMap();
        expect(argMap[SSHNPArg.fromArg.name], equals('@myClientAtSign'));
        expect(argMap[SSHNPArg.toArg.name], equals('@mySshnpdAtSign'));
        expect(argMap[SSHNPArg.hostArg.name], equals('@myHost'));
        expect(argMap[SSHNPArg.deviceArg.name], equals('myDeviceName'));
        expect(argMap[SSHNPArg.portArg.name], equals(1234));
        expect(argMap[SSHNPArg.localPortArg.name], equals(2345));
        expect(
            argMap[SSHNPArg.identityFileArg.name], equals('.ssh/id_ed25519'));
        expect(argMap[SSHNPArg.identityPassphraseArg.name],
            equals('myPassphrase'));
        expect(argMap[SSHNPArg.sendSshPublicKeyArg.name], equals(true));
        expect(argMap[SSHNPArg.localSshOptionsArg.name],
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(argMap[SSHNPArg.remoteUserNameArg.name], equals('myUsername'));
        expect(argMap[SSHNPArg.verboseArg.name], equals(true));
        expect(argMap[SSHNPArg.rootDomainArg.name], equals('root.atsign.wtf'));
        expect(argMap[SSHNPArg.localSshdPortArg.name], equals(4567));
        expect(argMap[SSHNPArg.remoteSshdPortArg.name], equals(2222));
        expect(argMap[SSHNPArg.idleTimeoutArg.name], equals(120));
        expect(argMap[SSHNPArg.addForwardsToTunnelArg.name], equals(true));
        expect(argMap[SSHNPArg.keyFileArg.name],
            equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(argMap[SSHNPArg.sshClientArg.name],
            equals(SupportedSshClient.dart.toString()));
        expect(argMap[SSHNPArg.sshAlgorithmArg.name],
            equals(SupportedSSHAlgorithm.rsa.toString()));
      });
      test('SSHNPParams.toJson', () {
        final params = SSHNPParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
          device: 'myDeviceName',
          port: 1234,
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          localSshdPort: 4567,
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          sshClient: SupportedSshClient.dart,
          sshAlgorithm: SupportedSSHAlgorithm.rsa,
        );
        final json = params.toJson();
        final parsedParams = SSHNPParams.fromJson(json);
        expect(parsedParams.clientAtSign, equals('@myClientAtSign'));
        expect(parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(parsedParams.host, equals('@myHost'));
        expect(parsedParams.device, equals('myDeviceName'));
        expect(parsedParams.port, equals(1234));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.identityFile, equals('.ssh/id_ed25519'));
        expect(parsedParams.identityPassphrase, equals('myPassphrase'));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.verbose, equals(true));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.localSshdPort, equals(4567));
        expect(parsedParams.remoteSshdPort, equals(2222));
        expect(parsedParams.idleTimeout, equals(120));
        expect(parsedParams.addForwardsToTunnel, equals(true));
        expect(parsedParams.atKeysFilePath,
            equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(parsedParams.sshClient, equals(SupportedSshClient.dart));
        expect(parsedParams.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
    }); // group('SSHNPParams functions')
  }); // group('SSHNPParams')

  group('SSHNPPartialParams', () {
    test('public API test', () {
      final partialParams = SSHNPPartialParams();
      expect(partialParams, isNotNull);
      expect(partialParams.clientAtSign, isA<String?>());
      expect(partialParams.sshnpdAtSign, isA<String?>());
      expect(partialParams.host, isA<String?>());
      expect(partialParams.device, isA<String?>());
      expect(partialParams.port, isA<int?>());
      expect(partialParams.localPort, isA<int?>());
      expect(partialParams.identityFile, isA<String?>());
      expect(partialParams.identityPassphrase, isA<String?>());
      expect(partialParams.sendSshPublicKey, isA<bool?>());
      expect(partialParams.localSshOptions, isA<List<String>?>());
      expect(partialParams.remoteUsername, isA<String?>());
      expect(partialParams.verbose, isA<bool?>());
      expect(partialParams.rootDomain, isA<String?>());
      expect(partialParams.localSshdPort, isA<int?>());
      expect(partialParams.legacyDaemon, isA<bool?>());
      expect(partialParams.remoteSshdPort, isA<int?>());
      expect(partialParams.idleTimeout, isA<int?>());
      expect(partialParams.addForwardsToTunnel, isA<bool?>());
      expect(partialParams.atKeysFilePath, isA<String?>());
      expect(partialParams.sshClient, isA<SupportedSshClient?>());
      expect(partialParams.sshAlgorithm, isA<SupportedSSHAlgorithm?>());
      expect(partialParams.profileName, isA<String?>());
      expect(partialParams.listDevices, isA<bool?>());
    });

    group('SSHNPPartialParams final variables', () {
      test('SSHNPPartialParams.clientAtSign test', () {
        final params = SSHNPPartialParams(clientAtSign: '@myClientAtSign');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SSHNPPartialParams.sshnpdAtSign test', () {
        final params = SSHNPPartialParams(sshnpdAtSign: '@mySshnpdAtSign');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SSHNPPartialParams.host test', () {
        final params = SSHNPPartialParams(host: '@myHost');
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPPartialParams.device test', () {
        final params = SSHNPPartialParams(device: 'myDeviceName');
        expect(params.device, equals('myDeviceName'));
      });
      test('SSHNPPartialParams.port test', () {
        final params = SSHNPPartialParams(port: 1234);
        expect(params.port, equals(1234));
      });
      test('SSHNPPartialParams.localPort test', () {
        final params = SSHNPPartialParams(localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SSHNPPartialParams.identityFile test', () {
        final params = SSHNPPartialParams(identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SSHNPPartialParams.identityPassphrase test', () {
        final params = SSHNPPartialParams(identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SSHNPPartialParams.sendSshPublicKey test', () {
        final params = SSHNPPartialParams(sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SSHNPPartialParams.localSshOptions test', () {
        final params = SSHNPPartialParams(
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SSHNPPartialParams.remoteUsername test', () {
        final params = SSHNPPartialParams(remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SSHNPPartialParams.verbose test', () {
        final params = SSHNPPartialParams(verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SSHNPPartialParams.rootDomain test', () {
        final params = SSHNPPartialParams(rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SSHNPPartialParams.localSshdPort test', () {
        final params = SSHNPPartialParams(localSshdPort: 4567);
        expect(params.localSshdPort, equals(4567));
      });
      test('SSHNPPartialParams.legacyDaemon test', () {
        final params = SSHNPPartialParams(legacyDaemon: true);
        expect(params.legacyDaemon, equals(true));
      });
      test('SSHNPPartialParams.remoteSshdPort test', () {
        final params = SSHNPPartialParams(remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SSHNPPartialParams.idleTimeout test', () {
        final params = SSHNPPartialParams(idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SSHNPPartialParams.addForwardsToTunnel test', () {
        final params = SSHNPPartialParams(addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SSHNPPartialParams.atKeysFilePath test', () {
        final params = SSHNPPartialParams(
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SSHNPPartialParams.sshClient test', () {
        final params = SSHNPPartialParams(sshClient: SupportedSshClient.dart);
        expect(params.sshClient, equals(SupportedSshClient.dart));
      });
      test('SSHNPPartialParams.sshAlgorithm test', () {
        final params =
            SSHNPPartialParams(sshAlgorithm: SupportedSSHAlgorithm.rsa);
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPPartialParams.profileName test', () {
        final params = SSHNPPartialParams(profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SSHNPPartialParams.listDevices test', () {
        final params = SSHNPPartialParams(listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SSHNPPartialParams final variables')
    group('SSHNPPartialParams factories', () {
      test('SSHNPPartialParams.empty() test', () {
        final params = SSHNPPartialParams.empty();
        expect(params.profileName, isNull);
        expect(params.clientAtSign, isNull);
        expect(params.sshnpdAtSign, isNull);
        expect(params.host, isNull);
        expect(params.device, isNull);
        expect(params.port, isNull);
        expect(params.localPort, isNull);
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(params.sendSshPublicKey, isNull);
        expect(params.localSshOptions, isNull);
        expect(params.verbose, isNull);
        expect(params.remoteUsername, isNull);
        expect(params.rootDomain, isNull);
        expect(params.localSshdPort, isNull);
        expect(params.legacyDaemon, isNull);
        expect(params.remoteSshdPort, isNull);
        expect(params.idleTimeout, isNull);
        expect(params.addForwardsToTunnel, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.sshClient, isNull);
        expect(params.sshAlgorithm, isNull);
        expect(params.listDevices, isNull);
      });
      test('SSHNPPartialParams.merge() test (overrides take priority)', () {
        final params = SSHNPPartialParams.merge(
          SSHNPPartialParams.empty(),
          SSHNPPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            host: '@myHost',
            device: 'myDeviceName',
            port: 1234,
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            localSshdPort: 4567,
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshClient: SupportedSshClient.dart,
            sshAlgorithm: SupportedSSHAlgorithm.rsa,
          ),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPPartialParams.merge() test (null coalesce values)', () {
        final params = SSHNPPartialParams.merge(
          SSHNPPartialParams(
            clientAtSign: '@myClientAtSign',
            sshnpdAtSign: '@mySshnpdAtSign',
            host: '@myHost',
            device: 'myDeviceName',
            port: 1234,
            localPort: 2345,
            identityFile: '.ssh/id_ed25519',
            identityPassphrase: 'myPassphrase',
            sendSshPublicKey: true,
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
            remoteUsername: 'myUsername',
            verbose: true,
            rootDomain: 'root.atsign.wtf',
            localSshdPort: 4567,
            remoteSshdPort: 2222,
            idleTimeout: 120,
            addForwardsToTunnel: true,
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
            sshClient: SupportedSshClient.dart,
            sshAlgorithm: SupportedSSHAlgorithm.rsa,
          ),
          SSHNPPartialParams.empty(),
        );
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      // TODO write tests for SSHNPPartialParams.fromFile()
      test('SSHNPPartial.fromConfigLines() test', () {
        final params = SSHNPParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
          device: 'myDeviceName',
          port: 1234,
          localPort: 2345,
          identityFile: '.ssh/id_ed25519',
          identityPassphrase: 'myPassphrase',
          sendSshPublicKey: true,
          localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80'],
          remoteUsername: 'myUsername',
          verbose: true,
          rootDomain: 'root.atsign.wtf',
          localSshdPort: 4567,
          remoteSshdPort: 2222,
          idleTimeout: 120,
          addForwardsToTunnel: true,
          atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys',
          sshClient: SupportedSshClient.dart,
          sshAlgorithm: SupportedSSHAlgorithm.rsa,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SSHNPPartialParams.fromConfigLines('myProfile', configLines);
        expect(parsedParams.profileName, equals('myProfile'));
        expect(parsedParams.clientAtSign, equals('@myClientAtSign'));
        expect(parsedParams.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(parsedParams.host, equals('@myHost'));
        expect(parsedParams.device, equals('myDeviceName'));
        expect(parsedParams.port, equals(1234));
        expect(parsedParams.localPort, equals(2345));
        expect(parsedParams.sendSshPublicKey, equals(true));
        expect(parsedParams.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(parsedParams.remoteUsername, equals('myUsername'));
        expect(parsedParams.verbose, equals(true));
        expect(parsedParams.rootDomain, equals('root.atsign.wtf'));
        expect(parsedParams.localSshdPort, equals(4567));
        expect(parsedParams.remoteSshdPort, equals(2222));
      });
      test('SSHNPPartialParams.fromJson() test', () {
        String json = '{'
            '"${SSHNPArg.profileNameArg.name}": "myProfile",'
            '"${SSHNPArg.fromArg.name}": "@myClientAtSign",'
            '"${SSHNPArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SSHNPArg.hostArg.name}": "@myHost",'
            '"${SSHNPArg.deviceArg.name}": "myDeviceName",'
            '"${SSHNPArg.portArg.name}": 1234,'
            '"${SSHNPArg.localPortArg.name}": 2345,'
            '"${SSHNPArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SSHNPArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SSHNPArg.sendSshPublicKeyArg.name}": true,'
            '"${SSHNPArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SSHNPArg.remoteUserNameArg.name}": "myUsername",'
            '"${SSHNPArg.verboseArg.name}": true,'
            '"${SSHNPArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SSHNPArg.localSshdPortArg.name}": 4567,'
            '"${SSHNPArg.legacyDaemonArg.name}": true,'
            '"${SSHNPArg.remoteSshdPortArg.name}": 2222,'
            '"${SSHNPArg.idleTimeoutArg.name}": 120,'
            '"${SSHNPArg.addForwardsToTunnelArg.name}": true,'
            '"${SSHNPArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SSHNPArg.sshClientArg.name}": "${SupportedSshClient.dart.toString()}",'
            '"${SSHNPArg.sshAlgorithmArg.name}": "${SupportedSSHAlgorithm.rsa.toString()}"'
            '}';

        final params = SSHNPPartialParams.fromJson(json);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPPartialParams.fromArgMap() test', () {
        final params = SSHNPPartialParams.fromArgMap({
          SSHNPArg.profileNameArg.name: 'myProfile',
          SSHNPArg.fromArg.name: '@myClientAtSign',
          SSHNPArg.toArg.name: '@mySshnpdAtSign',
          SSHNPArg.hostArg.name: '@myHost',
          SSHNPArg.deviceArg.name: 'myDeviceName',
          SSHNPArg.portArg.name: 1234,
          SSHNPArg.localPortArg.name: 2345,
          SSHNPArg.identityFileArg.name: '.ssh/id_ed25519',
          SSHNPArg.identityPassphraseArg.name: 'myPassphrase',
          SSHNPArg.sendSshPublicKeyArg.name: true,
          SSHNPArg.localSshOptionsArg.name: [
            '-L 127.0.01:8080:127.0.0.1:80'
          ],
          SSHNPArg.remoteUserNameArg.name: 'myUsername',
          SSHNPArg.verboseArg.name: true,
          SSHNPArg.rootDomainArg.name: 'root.atsign.wtf',
          SSHNPArg.localSshdPortArg.name: 4567,
          SSHNPArg.legacyDaemonArg.name: true,
          SSHNPArg.remoteSshdPortArg.name: 2222,
          SSHNPArg.idleTimeoutArg.name: 120,
          SSHNPArg.addForwardsToTunnelArg.name: true,
          SSHNPArg.keyFileArg.name: '~/.atsign/@myAtsign_keys.atKeys',
          SSHNPArg.sshClientArg.name: SupportedSshClient.dart.toString(),
          SSHNPArg.sshAlgorithmArg.name: SupportedSSHAlgorithm.rsa.toString(),
        });
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
      test('SSHNPPartialParams.fromArgList() test', () {
       final argList = [
          '--${SSHNPArg.profileNameArg.name}',
          'myProfile',
          '--${SSHNPArg.fromArg.name}',
          '@myClientAtSign',
          '--${SSHNPArg.toArg.name}',
          '@mySshnpdAtSign',
          '--${SSHNPArg.hostArg.name}',
          '@myHost',
          '--${SSHNPArg.deviceArg.name}',
          'myDeviceName',
          '--${SSHNPArg.portArg.name}',
          '1234',
          '--${SSHNPArg.localPortArg.name}',
          '2345',
          '--${SSHNPArg.identityFileArg.name}',
          '.ssh/id_ed25519',
          '--${SSHNPArg.identityPassphraseArg.name}',
          'myPassphrase',
          '--${SSHNPArg.sendSshPublicKeyArg.name}',
          'true',
          '--${SSHNPArg.localSshOptionsArg.name}',
          '-L 127.0.01:8080:127.0.0.1:80',
          '--${SSHNPArg.remoteUserNameArg.name}',
          'myUsername',
          '--${SSHNPArg.verboseArg.name}',
          'true',
          '--${SSHNPArg.rootDomainArg.name}',
          'root.atsign.wtf',
          '--${SSHNPArg.localSshdPortArg.name}',
          '4567',
          '--${SSHNPArg.legacyDaemonArg.name}',
          'true',
          '--${SSHNPArg.remoteSshdPortArg.name}',
          '2222',
          '--${SSHNPArg.idleTimeoutArg.name}',
          '120',
          '--${SSHNPArg.addForwardsToTunnelArg.name}',
          'true',
          '--${SSHNPArg.keyFileArg.name}',
          '~/.atsign/@myAtsign_keys.atKeys',
          '--${SSHNPArg.sshClientArg.name}',
          SupportedSshClient.dart.toString(),
          '--${SSHNPArg.sshAlgorithmArg.name}',
          SupportedSSHAlgorithm.rsa.toString(),
       ];
       final params = SSHNPPartialParams.fromArgList(argList);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.identityFile, equals('.ssh/id_ed25519'));
        expect(params.identityPassphrase, equals('myPassphrase'));
        expect(params.sendSshPublicKey, equals(true));
        expect(params.localSshOptions,
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSSHAlgorithm.rsa));
      });
    }); // group('SSHNPPartialParams factories')
  }); // group('SSHNPPartialParams')
}
