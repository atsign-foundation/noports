import 'dart:async';
import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:http2/http2.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/sshrv.dart';
import 'package:dartssh2/dartssh2.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _deviceAtSignController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();

  Future<void> onPressed() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    String clientAtSign = atClient.getCurrentAtSign()!;
    String deviceAtSign = _deviceAtSignController.text;
    String deviceName = _deviceNameController.text;
    String host = _hostController.text;

    // Generate ephemeral key pair for the device
    SSHNPParams params = SSHNPParams(
      clientAtSign: clientAtSign,
      sshnpdAtSign: deviceAtSign,
      host: host,
      device: deviceName,
      idleTimeout: 30,
      sshClient: SupportedSshClient.dart.cliArg,
    );

    SSHNP sshnp = await SSHNP.fromParams(
      params,
      atClient: atClient,
      sshrvGenerator: SSHRV.dart,
    );

    await sshnp.init();
    SSHNPResult result = await sshnp.run();
    if (result is! SSHNPCommand<SSHClient>) {
      // TODO handle error
      return;
    }

    if (result.connectionBean == null) {
      // TODO handle error
      return;
    }

    // Since we are using the pure dart ssh client, we can expect that the result
    // contains a non-null sshClient.
    final forward = await result.connectionBean!.forwardLocal('localhost', 80);
    final transport =
        ClientTransportConnection.viaStreams(forward.stream, forward.sink);
    final stream = transport.makeRequest(
      [
        Header.ascii(':method', 'GET'),
        Header.ascii(':path', '/'),
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
          print('HEADER: $name: $value');
        }
      } else if (message is DataStreamMessage) {
        print(utf8.decode(message.bytes));
      }
    }
    await transport.finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pull webserver page'),
      ),
      body: Center(
        child: Column(children: [
          TextField(
            controller: _deviceAtSignController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device AtSign',
            ),
          ),
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device Name',
            ),
          ),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Host',
            ),
          ),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('Load Data'),
          )
        ]),
      ),
    );
  }
}
