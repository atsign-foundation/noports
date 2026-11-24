import 'dart:io';
import 'package:npe2e/noports_version.dart';

enum ClientBinaryType { sshnp, npt, srv, npp_client, at_activate, srvd }

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
