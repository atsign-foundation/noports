import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../utils/sizes.dart';
import '../widgets/app_navigation_rail.dart';

// * Once the onboarding process is completed you will be taken to this screen
class NewScreen extends StatelessWidget {
  const NewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // * Getting the AtClientManager instance to use below
    AtClientManager atClientManager = AtClientManager.getInstance();
    final strings = AppLocalizations.of(context)!;

    bool connect() {
      // SSHNP(atClient: atClient, sshnpdAtSign: sshnpdAtSign, device: device, username: username, homeDirectory: homeDirectory, sessionId: sessionId, localSshOptions: localSshOptions, host: host, port: port, localPort: localPort)
      return true;
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            const AppNavigationRail(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(strings.addNewConnection),
                  Form(
                      child: Column(children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: strings.sshnpdAtSign,
                        hintText: strings.sshnpdAtSignHint,
                      ),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: strings.device,
                        hintText: strings.deviceHint,
                      ),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: strings.username,
                        hintText: strings.usernameHint,
                      ),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: strings.homeDirectory,
                        hintText: strings.homeDirectoryHint,
                      ),
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: strings.sessionId,
                      ),
                    ),
                    Switch(value: false, onChanged: (newValue) {}),
                    ToggleButtons(
                        isSelected: const <bool>[false, false],
                        children: [Text(strings.sendSshPublicKey), Text(strings.rsa)])
                  ]))
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
