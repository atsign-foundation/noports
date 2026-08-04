import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/policy/view/policy_view.dart';

class PolicyPageArguments {
  final Atsign atsign;

  PolicyPageArguments(this.atsign);
}

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PolicyPageArguments args =
        ModalRoute.of(context)!.settings.arguments as PolicyPageArguments;
    return PolicyView(atsign: args.atsign);
  }
}
