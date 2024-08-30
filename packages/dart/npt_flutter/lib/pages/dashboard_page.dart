import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/routes.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connections"),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pushNamed(Routes.settings);
              }
            },
            child: const Text("Settings"),
          ),
        ],
      ),
      body: const ProfileListView(),
    );
  }
}
