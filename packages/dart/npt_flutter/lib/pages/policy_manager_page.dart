import 'package:flutter/material.dart';
import 'package:npt_flutter/features/policy_manager/view/policy_manager_view.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';

class PolicyManagerPageArguments {
  final String? atSign;

  PolicyManagerPageArguments({this.atSign});
}

class PolicyManagerPage extends StatelessWidget {
  const PolicyManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PolicyManagerPageArguments args = ModalRoute.of(context)!.settings.arguments as PolicyManagerPageArguments;
    return Scaffold(
      body: PolicyManagerView(atSign: args.atSign),
    );
  }
}
