import 'dart:io';
import 'package:e2e_all_v2/language.dart';

enum ClientBinaryType {
  sshnp,
  npt,
  srv,
  npp_client,
  at_activate,
}

String getDartSourcePath(ClientBinaryType binaryType) {
  switch(binaryType) {
    case ClientBinaryType.sshnp:
      return 'packages/dart/sshnoports/bin/sshnp.dart';
    case ClientBinaryType.npt:
      return 'packages/dart/sshnoports/bin/npt.dart';
    case ClientBinaryType.srv:
      return 'packages/dart/sshnoports/bin/srv.dart';
    case ClientBinaryType.npp_client:
      return 'packages/dart/sshnoports/bin/npp_client.dart';
    case ClientBinaryType.at_activate:
      return 'packages/dart/sshnoports/bin/at_activate.dart';
    default:
      throw Exception('Unsupported ClientBinaryType: ${binaryType.name}');
  }
}

class ClientBinary {
  final ClientBinaryType binaryType; // sshnp, npt, srv, npp_client, etc,.
  final Language language; // dart or c
  final String version; // "current", "v5.9.4", "v5.11.2", "v5.13.0"
  final File file; // binary

  ClientBinary({
    required this.binaryType,
    required this.language,
    required this.version,
    required this.file,
  });

  Future<bool> exists() async {
    return file.exists();
  }
}
