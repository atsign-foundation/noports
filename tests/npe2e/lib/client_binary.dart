import 'dart:io';
import 'package:npe2e/noports_version.dart';

enum ClientBinaryType { sshnp, npt, srv, npp_client, at_activate }

class ClientBinary {
  final NoPortsVersion noPortsVersion;
  final ClientBinaryType binaryType; // sshnp, npt, srv, npp_client, etc,.
  final File file; // binary

  ClientBinary({
    required this.binaryType,
    required this.noPortsVersion,
    required this.file,
  });

  Future<bool> exists() async {
    return file.exists();
  }
}

String getDartSourcePath(ClientBinaryType binaryType) {
  switch (binaryType) {
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
  }
}
