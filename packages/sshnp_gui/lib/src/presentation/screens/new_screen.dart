import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../utils/sizes.dart';
import '../widgets/app_navigation_rail.dart';

// * Once the onboarding process is completed you will be taken to this screen
class NewScreen extends StatefulWidget {
  const NewScreen({Key? key}) : super(key: key);

  @override
  State<NewScreen> createState() => _NewScreenState();
}

class _NewScreenState extends State<NewScreen> {
  bool isVerbose = false;
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
                  Text(
                    strings.addNewConnection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  gapH10,
                  Form(
                    child: Row(
                      children: [
                        SizedBox(
                          height: 314,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CustomTextFormField(
                              labelText: strings.from,
                            ),
                            gapH10,
                            CustomTextFormField(labelText: strings.device),
                            gapH10,
                            CustomTextFormField(labelText: strings.port),
                            gapH10,
                            CustomTextFormField(labelText: strings.sshPublicKey),
                            gapH10,
                            Row(
                              children: [
                                Text(strings.verbose),
                                gapW12,
                                Switch(
                                    value: isVerbose,
                                    onChanged: (newValue) {
                                      setState(() {
                                        isVerbose = newValue;
                                      });
                                    }),
                              ],
                            ),
                            gapH10,
                            ElevatedButton(
                              onPressed: () {},
                              child: Text(strings.connect),
                            ),
                          ]),
                        ),
                        gapW12,
                        SizedBox(
                          height: 314,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CustomTextFormField(labelText: strings.to),
                            gapH10,
                            CustomTextFormField(labelText: strings.host),
                            gapH10,
                            CustomTextFormField(labelText: strings.localPort),
                            gapH10,
                            CustomTextFormField(labelText: strings.localSshOptions),
                            gapH10,
                            CustomTextFormField(labelText: strings.localSshOptions),
                            gapH20,
                            TextButton(onPressed: () {}, child: Text(strings.cancel))
                          ]),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField({
    super.key,
    required this.labelText,
    this.hintText,
    this.width = 192,
    this.height = 33,
  });

  final String labelText;
  final String? hintText;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextFormField(
        decoration: InputDecoration(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          labelText: labelText,
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}


// Container(
//       width: 192,
//       height: 33,
//       decoration: ShapeDecoration(
//         color: const Color(0xFF2F2F2F),
//         shape: RoundedRectangleBorder(
//           side: const BorderSide(width: 1, color: Colors.white),
//           borderRadius: BorderRadius.circular(2),
//         ),
//       ),
//       child: TextFormField(
//         decoration: InputDecoration(
//           labelText: strings.sshnpdAtSign,
//           hintText: strings.sshnpdAtSignHint,
//           hintStyle: Theme.of(context).textTheme.bodyLarge,
//         ),
//       ),
//     );