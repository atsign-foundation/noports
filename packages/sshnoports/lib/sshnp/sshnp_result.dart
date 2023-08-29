part of 'sshnp.dart';

abstract class SSHNPResult {}

const _optionsWithPrivateKey = [
  '-o StrictHostKeyChecking=accept-new',
  '-o IdentitiesOnly=yes'
];

class SSHNPFailed extends SSHNPResult {
  final String message;

  SSHNPFailed(this.message);

  @override
  String toString() {
    return message;
  }
}

class SSHCommand extends SSHNPResult {
  static const String command = 'ssh';

  final int localPort;
  final String remoteUsername;
  final String host;
  final String? privateKeyFileName;

  final List<String> sshOptions;

  SSHCommand.base({
    required this.localPort,
    required this.remoteUsername,
    required this.host,
    this.privateKeyFileName,
  }) : sshOptions = (shouldIncludePrivateKey(privateKeyFileName)
            ? _optionsWithPrivateKey
            : []);

  static bool shouldIncludePrivateKey(String? privateKeyFileName) =>
      privateKeyFileName != null &&
      privateKeyFileName.isNotEmpty &&
      privateKeyFileName != 'false';

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write(command);
    sb.write(' ');
    sb.write('-p $localPort');
    sb.write(' ');
    sb.write(sshOptions.join(' '));
    sb.write(' ');
    sb.write('$remoteUsername@$host');
    if (shouldIncludePrivateKey(privateKeyFileName)) {
      sb.write(' ');
      sb.write('-i $privateKeyFileName');
    }
    return sb.toString();
  }
}
