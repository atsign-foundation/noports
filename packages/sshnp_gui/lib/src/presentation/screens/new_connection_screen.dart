import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/new_profile_form.dart';

import '../../utils/sizes.dart';
import '../widgets/navigation/app_navigation_rail.dart';

// * Once the onboarding process is completed you will be taken to this screen
class NewConnectionScreen extends StatefulWidget {
  const NewConnectionScreen({Key? key}) : super(key: key);

  @override
  State<NewConnectionScreen> createState() => _NewConnectionScreenState();
}

class _NewConnectionScreenState extends State<NewConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

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
                  const Expanded(child: NewProfileForm())
                ]),
              ),
            ),
          ],
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