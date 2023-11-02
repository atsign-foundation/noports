import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';
import 'package:test/test.dart';

void main() {
  group('SSHNPParams', () {
    test('public API test', () {
      final params = SshnpParams(clientAtSign: '', sshnpdAtSign: '', host: '');
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
      expect(params.sshAlgorithm, isA<SupportedSshAlgorithm>());
      expect(params.profileName, isA<String?>());
      expect(params.listDevices, isA<bool>());
      expect(params.toConfigLines(), isA<List<String>>());
      expect(params.toArgMap(), isA<Map<String, dynamic>>());
      expect(params.toJson(), isA<String>());
    });

    group('SSHNPParams final variables', () {
      test('SSHNPParams.clientAtSign test', () {
        final params = SshnpParams(
            clientAtSign: '@myClientAtSign', sshnpdAtSign: '', host: '');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SSHNPParams.sshnpdAtSign test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '@mySshnpdAtSign', host: '');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SSHNPParams.host test', () {
        final params =
            SshnpParams(clientAtSign: '', sshnpdAtSign: '', host: '@myHost');
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPParams.device test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            device: 'myDeviceName');
        expect(params.device, equals('myDeviceName'));
      });
      test('SSHNPParams.port test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', port: 1234);
        expect(params.port, equals(1234));
      });
      test('SSHNPParams.localPort test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SSHNPParams.identityFile test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SSHNPParams.identityPassphrase test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SSHNPParams.sendSshPublicKey test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SSHNPParams.localSshOptions test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SSHNPParams.remoteUsername test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SSHNPParams.verbose test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SSHNPParams.rootDomain test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SSHNPParams.localSshdPort test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', localSshdPort: 4567);
        expect(params.localSshdPort, equals(4567));
      });
      test('SSHNPParams.legacyDaemon test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', legacyDaemon: true);
        expect(params.legacyDaemon, equals(true));
      });
      test('SSHNPParams.remoteSshdPort test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SSHNPParams.idleTimeout test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SSHNPParams.addForwardsToTunnel test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SSHNPParams.atKeysFilePath test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SSHNPParams.sshClient test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sshClient: SupportedSshClient.dart);
        expect(params.sshClient, equals(SupportedSshClient.dart));
      });
      test('SSHNPParams.sshAlgorithm test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            sshAlgorithm: SupportedSshAlgorithm.rsa);
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPParams.profileName test', () {
        final params = SshnpParams(
            clientAtSign: '',
            sshnpdAtSign: '',
            host: '',
            profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SSHNPParams.listDevices test', () {
        final params = SshnpParams(
            clientAtSign: '', sshnpdAtSign: '', host: '', listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SSHNPParams final variables')

    group('SSHNPParams factories', () {
      test('SSHNPParams.empty() test', () {
        final params = SshnpParams.empty();
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.host, equals(''));
        expect(params.device, equals(DefaultSshnpArgs.device));
        expect(params.port, equals(DefaultSshnpArgs.port));
        expect(params.localPort, equals(DefaultSshnpArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSshnpArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSshnpArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.localSshdPort, equals(DefaultArgs.localSshdPort));
        expect(params.legacyDaemon, equals(DefaultSshnpArgs.legacyDaemon));
        expect(params.listDevices, equals(DefaultSshnpArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
        expect(params.sshClient, equals(DefaultSshnpArgs.sshClient));
        expect(params.sshAlgorithm, equals(DefaultArgs.sshAlgorithm));
      });
      test('SSHNPParams.merge() test (overrides take priority)', () {
        final params = SshnpParams.merge(
          SshnpParams.empty(),
          SshnpPartialParams(
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
            sshAlgorithm: SupportedSshAlgorithm.rsa,
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPParams.merge() test (null coalesce values)', () {
        final params =
            SshnpParams.merge(SshnpParams.empty(), SshnpPartialParams());
        expect(params.profileName, equals(''));
        expect(params.clientAtSign, equals(''));
        expect(params.sshnpdAtSign, equals(''));
        expect(params.host, equals(''));
        expect(params.device, equals(DefaultSshnpArgs.device));
        expect(params.port, equals(DefaultSshnpArgs.port));
        expect(params.localPort, equals(DefaultSshnpArgs.localPort));
        expect(params.identityFile, isNull);
        expect(params.identityPassphrase, isNull);
        expect(
            params.sendSshPublicKey, equals(DefaultSshnpArgs.sendSshPublicKey));
        expect(
            params.localSshOptions, equals(DefaultSshnpArgs.localSshOptions));
        expect(params.verbose, equals(DefaultArgs.verbose));
        expect(params.remoteUsername, isNull);
        expect(params.atKeysFilePath, isNull);
        expect(params.rootDomain, equals(DefaultArgs.rootDomain));
        expect(params.localSshdPort, equals(DefaultArgs.localSshdPort));
        expect(params.legacyDaemon, equals(DefaultSshnpArgs.legacyDaemon));
        expect(params.listDevices, equals(DefaultSshnpArgs.listDevices));
        expect(params.remoteSshdPort, equals(DefaultArgs.remoteSshdPort));
        expect(params.idleTimeout, equals(DefaultArgs.idleTimeout));
        expect(params.addForwardsToTunnel,
            equals(DefaultArgs.addForwardsToTunnel));
        expect(params.sshClient, equals(DefaultSshnpArgs.sshClient));
        expect(params.sshAlgorithm, equals(DefaultArgs.sshAlgorithm));
      });
      test('SSHNPParams.fromJson() test', () {
        String json = '{'
            '"${SshnpArg.profileNameArg.name}": "myProfile",'
            '"${SshnpArg.fromArg.name}": "@myClientAtSign",'
            '"${SshnpArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SshnpArg.hostArg.name}": "@myHost",'
            '"${SshnpArg.deviceArg.name}": "myDeviceName",'
            '"${SshnpArg.portArg.name}": 1234,'
            '"${SshnpArg.localPortArg.name}": 2345,'
            '"${SshnpArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SshnpArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SshnpArg.sendSshPublicKeyArg.name}": true,'
            '"${SshnpArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SshnpArg.remoteUserNameArg.name}": "myUsername",'
            '"${SshnpArg.verboseArg.name}": true,'
            '"${SshnpArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SshnpArg.localSshdPortArg.name}": 4567,'
            '"${SshnpArg.legacyDaemonArg.name}": true,'
            '"${SshnpArg.remoteSshdPortArg.name}": 2222,'
            '"${SshnpArg.idleTimeoutArg.name}": 120,'
            '"${SshnpArg.addForwardsToTunnelArg.name}": true,'
            '"${SshnpArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SshnpArg.sshClientArg.name}": "${SupportedSshClient.dart.toString()}",'
            '"${SshnpArg.sshAlgorithmArg.name}": "${SupportedSshAlgorithm.rsa.toString()}"'
            '}';

        final params = SshnpParams.fromJson(json);
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPParams.fromPartial() test', () {
        final partial = SshnpPartialParams(
          clientAtSign: '@myClientAtSign',
          sshnpdAtSign: '@mySshnpdAtSign',
          host: '@myHost',
        );
        final params = SshnpParams.fromPartial(partial);
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPParams.fromConfigLines() test', () {
        final configLines = [
          '${SshnpArg.fromArg.bashName} = @myClientAtSign',
          '${SshnpArg.toArg.bashName} = @mySshnpdAtSign',
          '${SshnpArg.hostArg.bashName} = @myHost',
          '${SshnpArg.deviceArg.bashName} = myDeviceName',
          '${SshnpArg.portArg.bashName} = 1234',
          '${SshnpArg.localPortArg.bashName} = 2345',
          '${SshnpArg.identityFileArg.bashName} = .ssh/id_ed25519',
          '${SshnpArg.identityPassphraseArg.bashName} = myPassphrase',
          '${SshnpArg.sendSshPublicKeyArg.bashName} = true',
          '${SshnpArg.localSshOptionsArg.bashName} = -L 127.0.01:8080:127.0.0.1:80',
          '${SshnpArg.remoteUserNameArg.bashName} = myUsername',
          '${SshnpArg.verboseArg.bashName} = true',
          '${SshnpArg.rootDomainArg.bashName} = root.atsign.wtf',
          '${SshnpArg.localSshdPortArg.bashName} = 4567',
          '${SshnpArg.legacyDaemonArg.bashName} = true',
          '${SshnpArg.remoteSshdPortArg.bashName} = 2222',
          '${SshnpArg.idleTimeoutArg.bashName} = 120',
          '${SshnpArg.addForwardsToTunnelArg.bashName} = true',
          '${SshnpArg.keyFileArg.bashName} = ~/.atsign/@myAtsign_keys.atKeys',
          '${SshnpArg.sshClientArg.bashName} = ${SupportedSshClient.dart.toString()}',
          '${SshnpArg.sshAlgorithmArg.bashName} = ${SupportedSshAlgorithm.rsa.toString()}',
        ];
        final params = SshnpParams.fromConfigLines('myProfile', configLines);
        expect(params.profileName, equals('myProfile'));
        expect(params.clientAtSign, equals('@myClientAtSign'));
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
        expect(params.host, equals('@myHost'));
        expect(params.device, equals('myDeviceName'));
        expect(params.port, equals(1234));
        expect(params.localPort, equals(2345));
        expect(params.sendSshPublicKey, equals(true));
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        final params = SshnpParams(
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
          sshAlgorithm: SupportedSshAlgorithm.rsa,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SshnpParams.fromConfigLines('myProfile', configLines);
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
        final params = SshnpParams(
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
          sshAlgorithm: SupportedSshAlgorithm.rsa,
        );
        final argMap = params.toArgMap();
        expect(argMap[SshnpArg.fromArg.name], equals('@myClientAtSign'));
        expect(argMap[SshnpArg.toArg.name], equals('@mySshnpdAtSign'));
        expect(argMap[SshnpArg.hostArg.name], equals('@myHost'));
        expect(argMap[SshnpArg.deviceArg.name], equals('myDeviceName'));
        expect(argMap[SshnpArg.portArg.name], equals(1234));
        expect(argMap[SshnpArg.localPortArg.name], equals(2345));
        expect(
            argMap[SshnpArg.identityFileArg.name], equals('.ssh/id_ed25519'));
        expect(argMap[SshnpArg.identityPassphraseArg.name],
            equals('myPassphrase'));
        expect(argMap[SshnpArg.sendSshPublicKeyArg.name], equals(true));
        expect(argMap[SshnpArg.localSshOptionsArg.name],
            equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(argMap[SshnpArg.remoteUserNameArg.name], equals('myUsername'));
        expect(argMap[SshnpArg.verboseArg.name], equals(true));
        expect(argMap[SshnpArg.rootDomainArg.name], equals('root.atsign.wtf'));
        expect(argMap[SshnpArg.localSshdPortArg.name], equals(4567));
        expect(argMap[SshnpArg.remoteSshdPortArg.name], equals(2222));
        expect(argMap[SshnpArg.idleTimeoutArg.name], equals(120));
        expect(argMap[SshnpArg.addForwardsToTunnelArg.name], equals(true));
        expect(argMap[SshnpArg.keyFileArg.name],
            equals('~/.atsign/@myAtsign_keys.atKeys'));
        expect(argMap[SshnpArg.sshClientArg.name],
            equals(SupportedSshClient.dart.toString()));
        expect(argMap[SshnpArg.sshAlgorithmArg.name],
            equals(SupportedSshAlgorithm.rsa.toString()));
      });
      test('SSHNPParams.toJson', () {
        final params = SshnpParams(
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
          sshAlgorithm: SupportedSshAlgorithm.rsa,
        );
        final json = params.toJson();
        final parsedParams = SshnpParams.fromJson(json);
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
        expect(parsedParams.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
    }); // group('SSHNPParams functions')
  }); // group('SSHNPParams')

  group('SSHNPPartialParams', () {
    test('public API test', () {
      final partialParams = SshnpPartialParams();
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
      expect(partialParams.sshAlgorithm, isA<SupportedSshAlgorithm?>());
      expect(partialParams.profileName, isA<String?>());
      expect(partialParams.listDevices, isA<bool?>());
    });

    group('SSHNPPartialParams final variables', () {
      test('SSHNPPartialParams.clientAtSign test', () {
        final params = SshnpPartialParams(clientAtSign: '@myClientAtSign');
        expect(params.clientAtSign, equals('@myClientAtSign'));
      });
      test('SSHNPPartialParams.sshnpdAtSign test', () {
        final params = SshnpPartialParams(sshnpdAtSign: '@mySshnpdAtSign');
        expect(params.sshnpdAtSign, equals('@mySshnpdAtSign'));
      });
      test('SSHNPPartialParams.host test', () {
        final params = SshnpPartialParams(host: '@myHost');
        expect(params.host, equals('@myHost'));
      });
      test('SSHNPPartialParams.device test', () {
        final params = SshnpPartialParams(device: 'myDeviceName');
        expect(params.device, equals('myDeviceName'));
      });
      test('SSHNPPartialParams.port test', () {
        final params = SshnpPartialParams(port: 1234);
        expect(params.port, equals(1234));
      });
      test('SSHNPPartialParams.localPort test', () {
        final params = SshnpPartialParams(localPort: 2345);
        expect(params.localPort, equals(2345));
      });
      test('SSHNPPartialParams.identityFile test', () {
        final params = SshnpPartialParams(identityFile: '.ssh/id_ed25519');
        expect(params.identityFile, equals('.ssh/id_ed25519'));
      });
      test('SSHNPPartialParams.identityPassphrase test', () {
        final params = SshnpPartialParams(identityPassphrase: 'myPassphrase');
        expect(params.identityPassphrase, equals('myPassphrase'));
      });
      test('SSHNPPartialParams.sendSshPublicKey test', () {
        final params = SshnpPartialParams(sendSshPublicKey: true);
        expect(params.sendSshPublicKey, equals(true));
      });
      test('SSHNPPartialParams.localSshOptions test', () {
        final params = SshnpPartialParams(
            localSshOptions: ['-L 127.0.01:8080:127.0.0.1:80']);
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
      });
      test('SSHNPPartialParams.remoteUsername test', () {
        final params = SshnpPartialParams(remoteUsername: 'myUsername');
        expect(params.remoteUsername, equals('myUsername'));
      });
      test('SSHNPPartialParams.verbose test', () {
        final params = SshnpPartialParams(verbose: true);
        expect(params.verbose, equals(true));
      });
      test('SSHNPPartialParams.rootDomain test', () {
        final params = SshnpPartialParams(rootDomain: 'root.atsign.wtf');
        expect(params.rootDomain, equals('root.atsign.wtf'));
      });
      test('SSHNPPartialParams.localSshdPort test', () {
        final params = SshnpPartialParams(localSshdPort: 4567);
        expect(params.localSshdPort, equals(4567));
      });
      test('SSHNPPartialParams.legacyDaemon test', () {
        final params = SshnpPartialParams(legacyDaemon: true);
        expect(params.legacyDaemon, equals(true));
      });
      test('SSHNPPartialParams.remoteSshdPort test', () {
        final params = SshnpPartialParams(remoteSshdPort: 2222);
        expect(params.remoteSshdPort, equals(2222));
      });
      test('SSHNPPartialParams.idleTimeout test', () {
        final params = SshnpPartialParams(idleTimeout: 120);
        expect(params.idleTimeout, equals(120));
      });
      test('SSHNPPartialParams.addForwardsToTunnel test', () {
        final params = SshnpPartialParams(addForwardsToTunnel: true);
        expect(params.addForwardsToTunnel, equals(true));
      });
      test('SSHNPPartialParams.atKeysFilePath test', () {
        final params = SshnpPartialParams(
            atKeysFilePath: '~/.atsign/@myAtsign_keys.atKeys');
        expect(
            params.atKeysFilePath, equals('~/.atsign/@myAtsign_keys.atKeys'));
      });
      test('SSHNPPartialParams.sshClient test', () {
        final params = SshnpPartialParams(sshClient: SupportedSshClient.dart);
        expect(params.sshClient, equals(SupportedSshClient.dart));
      });
      test('SSHNPPartialParams.sshAlgorithm test', () {
        final params =
            SshnpPartialParams(sshAlgorithm: SupportedSshAlgorithm.rsa);
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPPartialParams.profileName test', () {
        final params = SshnpPartialParams(profileName: 'myProfile');
        expect(params.profileName, equals('myProfile'));
      });
      test('SSHNPPartialParams.listDevices test', () {
        final params = SshnpPartialParams(listDevices: true);
        expect(params.listDevices, equals(true));
      });
    }); // group('SSHNPPartialParams final variables')
    group('SSHNPPartialParams factories', () {
      test('SSHNPPartialParams.empty() test', () {
        final params = SshnpPartialParams.empty();
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
        final params = SshnpPartialParams.merge(
          SshnpPartialParams.empty(),
          SshnpPartialParams(
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
            sshAlgorithm: SupportedSshAlgorithm.rsa,
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPPartialParams.merge() test (null coalesce values)', () {
        final params = SshnpPartialParams.merge(
          SshnpPartialParams(
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
            sshAlgorithm: SupportedSshAlgorithm.rsa,
          ),
          SshnpPartialParams.empty(),
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      // TODO write tests for SSHNPPartialParams.fromFile()
      test('SSHNPPartial.fromConfigLines() test', () {
        final params = SshnpParams(
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
          sshAlgorithm: SupportedSshAlgorithm.rsa,
        );
        final configLines = params.toConfigLines();
        // Since exact formatting is in question,
        // it is safer to trust that the parser works as expected
        // and just check that the lines are present
        final parsedParams =
            SshnpPartialParams.fromConfigLines('myProfile', configLines);
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
            '"${SshnpArg.profileNameArg.name}": "myProfile",'
            '"${SshnpArg.fromArg.name}": "@myClientAtSign",'
            '"${SshnpArg.toArg.name}": "@mySshnpdAtSign",'
            '"${SshnpArg.hostArg.name}": "@myHost",'
            '"${SshnpArg.deviceArg.name}": "myDeviceName",'
            '"${SshnpArg.portArg.name}": 1234,'
            '"${SshnpArg.localPortArg.name}": 2345,'
            '"${SshnpArg.identityFileArg.name}": ".ssh/id_ed25519",'
            '"${SshnpArg.identityPassphraseArg.name}": "myPassphrase",'
            '"${SshnpArg.sendSshPublicKeyArg.name}": true,'
            '"${SshnpArg.localSshOptionsArg.name}": ["-L 127.0.01:8080:127.0.0.1:80"],'
            '"${SshnpArg.remoteUserNameArg.name}": "myUsername",'
            '"${SshnpArg.verboseArg.name}": true,'
            '"${SshnpArg.rootDomainArg.name}": "root.atsign.wtf",'
            '"${SshnpArg.localSshdPortArg.name}": 4567,'
            '"${SshnpArg.legacyDaemonArg.name}": true,'
            '"${SshnpArg.remoteSshdPortArg.name}": 2222,'
            '"${SshnpArg.idleTimeoutArg.name}": 120,'
            '"${SshnpArg.addForwardsToTunnelArg.name}": true,'
            '"${SshnpArg.keyFileArg.name}": "~/.atsign/@myAtsign_keys.atKeys",'
            '"${SshnpArg.sshClientArg.name}": "${SupportedSshClient.dart.toString()}",'
            '"${SshnpArg.sshAlgorithmArg.name}": "${SupportedSshAlgorithm.rsa.toString()}"'
            '}';

        final params = SshnpPartialParams.fromJson(json);
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPPartialParams.fromArgMap() test', () {
        final params = SshnpPartialParams.fromArgMap({
          SshnpArg.profileNameArg.name: 'myProfile',
          SshnpArg.fromArg.name: '@myClientAtSign',
          SshnpArg.toArg.name: '@mySshnpdAtSign',
          SshnpArg.hostArg.name: '@myHost',
          SshnpArg.deviceArg.name: 'myDeviceName',
          SshnpArg.portArg.name: 1234,
          SshnpArg.localPortArg.name: 2345,
          SshnpArg.identityFileArg.name: '.ssh/id_ed25519',
          SshnpArg.identityPassphraseArg.name: 'myPassphrase',
          SshnpArg.sendSshPublicKeyArg.name: true,
          SshnpArg.localSshOptionsArg.name: ['-L 127.0.01:8080:127.0.0.1:80'],
          SshnpArg.remoteUserNameArg.name: 'myUsername',
          SshnpArg.verboseArg.name: true,
          SshnpArg.rootDomainArg.name: 'root.atsign.wtf',
          SshnpArg.localSshdPortArg.name: 4567,
          SshnpArg.legacyDaemonArg.name: true,
          SshnpArg.remoteSshdPortArg.name: 2222,
          SshnpArg.idleTimeoutArg.name: 120,
          SshnpArg.addForwardsToTunnelArg.name: true,
          SshnpArg.keyFileArg.name: '~/.atsign/@myAtsign_keys.atKeys',
          SshnpArg.sshClientArg.name: SupportedSshClient.dart.toString(),
          SshnpArg.sshAlgorithmArg.name: SupportedSshAlgorithm.rsa.toString(),
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
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
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
      test('SSHNPPartialParams.fromArgList() test', () {
        final argList = [
          '--${SshnpArg.profileNameArg.name}',
          'myProfile',
          '--${SshnpArg.fromArg.name}',
          '@myClientAtSign',
          '--${SshnpArg.toArg.name}',
          '@mySshnpdAtSign',
          '--${SshnpArg.hostArg.name}',
          '@myHost',
          '--${SshnpArg.deviceArg.name}',
          'myDeviceName',
          '--${SshnpArg.portArg.name}',
          '1234',
          '--${SshnpArg.localPortArg.name}',
          '2345',
          '--${SshnpArg.identityFileArg.name}',
          '.ssh/id_ed25519',
          '--${SshnpArg.identityPassphraseArg.name}',
          'myPassphrase',
          '--${SshnpArg.sendSshPublicKeyArg.name}',
          'true',
          '--${SshnpArg.localSshOptionsArg.name}',
          '-L 127.0.01:8080:127.0.0.1:80',
          '--${SshnpArg.remoteUserNameArg.name}',
          'myUsername',
          '--${SshnpArg.verboseArg.name}',
          'true',
          '--${SshnpArg.rootDomainArg.name}',
          'root.atsign.wtf',
          '--${SshnpArg.localSshdPortArg.name}',
          '4567',
          '--${SshnpArg.legacyDaemonArg.name}',
          'true',
          '--${SshnpArg.remoteSshdPortArg.name}',
          '2222',
          '--${SshnpArg.idleTimeoutArg.name}',
          '120',
          '--${SshnpArg.addForwardsToTunnelArg.name}',
          'true',
          '--${SshnpArg.keyFileArg.name}',
          '~/.atsign/@myAtsign_keys.atKeys',
          '--${SshnpArg.sshClientArg.name}',
          SupportedSshClient.dart.toString(),
          '--${SshnpArg.sshAlgorithmArg.name}',
          SupportedSshAlgorithm.rsa.toString(),
        ];
        final params = SshnpPartialParams.fromArgList(argList);
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
        expect(
            params.localSshOptions, equals(['-L 127.0.01:8080:127.0.0.1:80']));
        expect(params.remoteUsername, equals('myUsername'));
        expect(params.verbose, equals(true));
        expect(params.rootDomain, equals('root.atsign.wtf'));
        expect(params.localSshdPort, equals(4567));
        expect(params.legacyDaemon, equals(true));
        expect(params.remoteSshdPort, equals(2222));
        expect(params.idleTimeout, equals(120));
        expect(params.addForwardsToTunnel, equals(true));
        expect(params.sshClient, equals(SupportedSshClient.dart));
        expect(params.sshAlgorithm, equals(SupportedSshAlgorithm.rsa));
      });
    }); // group('SSHNPPartialParams factories')
  }); // group('SSHNPPartialParams')
}
