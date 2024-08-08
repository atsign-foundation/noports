import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below
    AtClientManager atClientManager = AtClientManager.getInstance();
    // * Getting the AtClient instance to use below
    AtClient atClient = atClientManager.atClient;

    // * From this widget onwards, you are fully onboarded!
    // * You can use the AtClient instance to perform operations as the onboared atSign
    return Scaffold(
      appBar: AppBar(
        title: const Text('What\'s my current @sign?'),
      ),
      body: Center(
        child: Column(children: [
          const Text('Successfully onboarded and navigated to FirstAppScreen'),

          // * Use the AtClient to get the current @sign
          Text('Current @sign: ${atClient.getCurrentAtSign()}')
        ]),
      ),
    );
  }
}
