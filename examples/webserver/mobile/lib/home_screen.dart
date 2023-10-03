import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sshnp_webserver_demo/api/mobile_endpoint.dart';

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

  Map<String, dynamic> headers = {};
  String message = '';

  Future<void> onPressed() async {
    String deviceAtSign = _deviceAtSignController.text;
    String deviceName = _deviceNameController.text;
    String host = _hostController.text;

    var (String message, Map<String, dynamic> headers) = await mobileEndpoint(
      deviceAtSign: deviceAtSign,
      deviceName: deviceName,
      host: host,
    );

    setState(() {
      message = message;
      headers = headers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pull webserver page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(children: [
          TextField(
            controller: _deviceAtSignController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device AtSign',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Device Name',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Host',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('Load Data'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Data',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Expanded(
            child: Container(
              width: MediaQuery.of(context).size.width - 48, // -48 for padding
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Headers:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(headers.toString()),
                      const SizedBox(height: 16),
                      const Text(
                        'Message:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
