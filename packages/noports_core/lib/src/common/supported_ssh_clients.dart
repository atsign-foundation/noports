enum SupportedSshClient {
  exec(cliArg: '/usr/bin/ssh'),
  dart(cliArg: 'pure-dart');

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
