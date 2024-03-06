import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/home_screen_widgets/home_screen_actions/new_profile_action.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class HomeScreenActions extends StatelessWidget {
  const HomeScreenActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // ImportProfileAction(),
        // gapW8,
        NewProfileAction(),
        gapW8,
      ],
    );
  }
}
