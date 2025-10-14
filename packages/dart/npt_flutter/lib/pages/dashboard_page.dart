import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ProfileListView());
  }
}
