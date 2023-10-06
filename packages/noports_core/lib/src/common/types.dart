import 'package:noports_core/sshrv.dart';

typedef SSHRVGenerator = SSHRV Function(String, int, {int localSshdPort});

enum SupportedSshClient {
  exec(cliArg: '/usr/bin/ssh'),
  dart(cliArg: 'dart');

  final String _cliArg;
  const SupportedSshClient({required String cliArg}) : _cliArg = cliArg;

  factory SupportedSshClient.fromString(String cliArg) {
    return SupportedSshClient.values.firstWhere(
      (arg) => arg._cliArg == cliArg,
      orElse: () => throw ArgumentError('Unsupported SSH client: $cliArg'),
    );
  }

  @override
  String toString() => _cliArg;
}

enum SupportedSSHAlgorithm {
  ed25519(cliArg: 'ssh-ed25519'),
  rsa(cliArg: 'ssh-rsa');

  final String _cliArg;
  const SupportedSSHAlgorithm({required String cliArg}) : _cliArg = cliArg;

  factory SupportedSSHAlgorithm.fromString(String cliArg) {
    return SupportedSSHAlgorithm.values.firstWhere(
      (arg) => arg._cliArg == cliArg,
      orElse: () => throw ArgumentError('Unsupported SSH algorithm: $cliArg'),
    );
  }

  @override
  String toString() => _cliArg;
}

enum SupportedIdentityType {
  file(cliArg: 'file'),
  ephemeral(cliArg: 'ephemeral');

  final String _cliArg;
  const SupportedIdentityType({required String cliArg}) : _cliArg = cliArg;

  factory SupportedIdentityType.fromString(String cliArg) {
    return SupportedIdentityType.values.firstWhere(
      (arg) => arg._cliArg == cliArg,
      orElse: () => throw ArgumentError('Unsupported Identity Type: $cliArg'),
    );
  }

  @override
  String toString() => _cliArg;
}
