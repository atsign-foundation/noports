import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:sshnp_webserver_demo/api/mobile_endpoint.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> headers = {};
  String message = '';

  Future<void> onPressed() async {
    await dotenv.load();
    String deviceAtSign = dotenv.get('TO');
    String host = dotenv.get('HOST');
    String deviceName = dotenv.get('DEVICE');
    if (context.mounted) {
      var (String message, Map<String, dynamic> headers) = await mobileEndpoint(
        deviceAtSign: deviceAtSign,
        deviceName: deviceName,
        host: host,
        context: context,
      );

      setState(() {
        message = message;
        headers = headers;
      });
    }
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              IconButton(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
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
