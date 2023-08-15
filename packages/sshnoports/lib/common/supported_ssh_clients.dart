enum SupportedSshClient {
  hostSsh(cliArg: '/usr/bin/ssh'),
  pureDart(cliArg: 'pure-dart');

  final String cliArg;
  const SupportedSshClient({required this.cliArg});
}
