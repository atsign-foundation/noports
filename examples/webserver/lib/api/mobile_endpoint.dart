import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart' hide StringBuffer;
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:http2/http2.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:sshnp_webserver_demo/widgets/custom_snack_bar.dart';

Future<(String, Map<String, dynamic>)> mobileEndpoint({
  required String deviceAtSign,
  required String deviceName,
  required String host,
  required BuildContext context,
}) async {
  AtClient atClient = AtClientManager.getInstance().atClient;
  String clientAtSign = atClient.getCurrentAtSign()!;

  Map<String, dynamic> headers = {};
  StringBuffer messageBuffer = StringBuffer();

  // Generate ephemeral key pair for the device
  SSHNPParams params = SSHNPParams(
    clientAtSign: clientAtSign,
    sshnpdAtSign: deviceAtSign,
    host: host,
    device: deviceName,
    idleTimeout: 30,
    sshClient: SupportedSshClient.dart.cliArg,
    verbose: true,
  );

  SSHNP sshnp = await SSHNP.fromParams(
    params,
    atClient: atClient,
    sshrvGenerator: SSHRV.dart,
  );

  await sshnp.init();
  SSHNPResult result = await sshnp.run();

  if (result is! SSHNPCommand<SSHClient>) {
    if (context.mounted) {
      CustomSnackBar.error(context: context, content: result.toString());
    }
    throw ('Unexpected value: result is not SSHNPCommand<SSHClient>, result is ${result.runtimeType}');
  }

  if (result.connectionBean == null) {
    if (context.mounted) {
      CustomSnackBar.error(
          context: context, content: 'Connection bean is null');
    }
    throw ('Unexpected value: result.connectionBean is null');
  }

  // Since we are using the pure dart ssh client, we can expect that the result
  // contains a non-null sshClient.
  final forward = await result.connectionBean!.forwardLocal('localhost', 80);
  final transport =
      ClientTransportConnection.viaStreams(forward.stream, forward.sink);
  final stream = transport.makeRequest(
    [
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', '/api/mobile_endpoint'),
      Header.ascii(':scheme', 'http'),
      Header.ascii(':authority', 'localhost'),
    ],
    endStream: true,
  );

  await for (var message in stream.incomingMessages) {
    if (message is HeadersStreamMessage) {
      for (var header in message.headers) {
        var name = utf8.decode(header.name);
        var value = utf8.decode(header.value);
        headers[name] = value;
      }
    } else if (message is DataStreamMessage) {
      messageBuffer.write(utf8.decode(message.bytes));
    }
  }
  await transport.finish();

  return (messageBuffer.toString(), headers);
}
