import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/features/policy/view/policy_view.dart';

class PolicyPageArguments {
  final String atSign;

  PolicyPageArguments(this.atSign);
}

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PolicyPageArguments args =
        ModalRoute.of(context)!.settings.arguments as PolicyPageArguments;
    return PolicyView(atSign: args.atSign);
  }
}
