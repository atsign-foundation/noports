import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/sizes.dart';
import '../widgets/app_navigation_rail.dart';

// * Once the onboarding process is completed you will be taken to this screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below
    AtClientManager atClientManager = AtClientManager.getInstance();

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
                  child: SvgPicture.asset(
                    'assets/images/noports_dark.svg',
                  ),
                ),

                // * Use the AtClientManager instance to get the AtClient
                // * Then use the AtClient to get the current @sign
                Text('Current @sign: ${atClientManager.atClient.getCurrentAtSign()}')
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
