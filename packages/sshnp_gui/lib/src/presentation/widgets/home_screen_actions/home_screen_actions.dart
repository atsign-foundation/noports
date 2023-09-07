import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/widgets/home_screen_actions/new_profile_action.dart';

class HomeScreenActions extends StatelessWidget {
  const HomeScreenActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [NewProfileAction()],
    );
  }
}
