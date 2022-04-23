import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

void sshLocal(
  String username,
  String port,
) async {
  final socket = await SSHSocket.connect('localhost', int.parse(port));
  print(username);
  print(socket);
  final client = SSHClient(
    socket,
    username: username,
    identities: [
          // A single private key file may contain multiple keys.
          ...SSHKeyPair.fromPem(await File('~/.ssh/GitHub_rsa').readAsString())
        ],
    onPasswordRequest: () {
      stdout.write('Password: ');
      stdin.echoMode = false;
      return stdin.readLineSync() ?? exit(1);
    },
  );
  final shell = await client.shell();
  stdout.addStream(shell.stdout);
  stderr.addStream(shell.stderr);
  stdin.cast<Uint8List>().listen(shell.write);

  await shell.done;

  client.close();
  await client.done;
}
