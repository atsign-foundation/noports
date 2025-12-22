import 'dart:io';

import 'package:at_commons/at_commons.dart';
import 'package:at_lookup/at_lookup.dart';

class ConnectivityChecker {
  final Duration timeout;

  ConnectivityChecker({this.timeout = const Duration(seconds: 5)});

  Future<void> atDirectory(AtRootDomain atDir, {Duration? timeout}) async {
    if (atDir.isProxyAddress) {
      await SecureSocket.connect(
        atDir.rootDomain.replaceFirst('proxy:', ''),
        atDir.rootPort,
        timeout: timeout ?? this.timeout,
      );
    } else {
      await SecureSocket.connect(
        atDir.rootDomain,
        atDir.rootPort,
        timeout: timeout ?? this.timeout,
      );
    }
  }

  Future<void> atServer(
    SecondaryAddressFinder saf,
    Atsign atSign, {
    Duration? timeout,
  }) async {
    SecondaryAddress addr = await saf.findSecondary(atSign);
    await SecureSocket.connect(
      addr.host,
      addr.port,
      timeout: timeout ?? this.timeout,
    );
  }

  Future<void> relay(String host, int port, {Duration? timeout}) async {
    await Socket.connect(host, port, timeout: timeout ?? this.timeout);
  }
}
