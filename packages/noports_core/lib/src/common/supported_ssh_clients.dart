enum SupportedSshClient {
  exec(cliArg: '/usr/bin/ssh'),
  dart(cliArg: 'pure-dart');

  final String cliArg;
  const SupportedSshClient({required this.cliArg});

  factory SupportedSshClient.fromCliArg(String cliArg) {
    switch (cliArg) {
      case '/usr/bin/ssh':
        return SupportedSshClient.exec;
      case 'pure-dart':
        return SupportedSshClient.dart;
      default:
        throw ArgumentError('Unsupported SSH client: $cliArg');
    }
  }
}
