import 'package:noports_core/sshrv.dart';

typedef SshrvGenerator<T> = Sshrv<T> Function(
  String,
  int, {
  required int localPort,
  required bool bindLocalPort,
  String? rvdAuthString,
  String? sessionAESKeyString,
  String? sessionIVString,
});

enum SupportedSshClient {
  openssh(cliArg: 'openssh'),
  dart(cliArg: 'dart');

  final String _cliArg;

  const SupportedSshClient({required String cliArg}) : _cliArg = cliArg;

  factory SupportedSshClient.fromString(String cliArg) {
    return SupportedSshClient.values.firstWhere(
      (arg) => arg._cliArg == cliArg.toLowerCase(),
      orElse: () => throw ArgumentError('Unsupported SSH client: $cliArg'),
    );
  }

  @override
  String toString() => _cliArg;
}

enum SupportedSshAlgorithm {
  ed25519(cliArg: 'ssh-ed25519'),
  rsa(cliArg: 'ssh-rsa');

  final String _cliArg;

  const SupportedSshAlgorithm({required String cliArg}) : _cliArg = cliArg;

  factory SupportedSshAlgorithm.fromString(String cliArg) {
    return SupportedSshAlgorithm.values.firstWhere(
      (arg) => arg._cliArg == cliArg,
      orElse: () => throw ArgumentError('Unsupported SSH algorithm: $cliArg'),
    );
  }

  @override
  String toString() => _cliArg;
}
