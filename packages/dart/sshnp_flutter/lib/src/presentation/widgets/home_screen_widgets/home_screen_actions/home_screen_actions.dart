import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/home_screen_widgets/home_screen_actions/new_profile_action.dart';

import '../../../../utility/sizes.dart';

class HomeScreenActions extends StatelessWidget {
  const HomeScreenActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // TODO: To be implemented as part of the enterprise version
        // ImportProfileAction(),
        // gapW8,
        NewProfileAction(),
        gapW8,
      ],
    );
  }
}
