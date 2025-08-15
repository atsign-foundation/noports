import 'package:flutter/material.dart';
import 'package:npt_flutter/features/policy_manager/view/policy_manager_view.dart';

class PolicyManagerPageArguments {
  final String atSign;

  PolicyManagerPageArguments(this.atSign);
}

class PolicyManagerPage extends StatelessWidget {
  const PolicyManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PolicyManagerPageArguments args = ModalRoute.of(context)!.settings.arguments as PolicyManagerPageArguments;
    return PolicyManagerView(atSign: args.atSign);
  }
}
