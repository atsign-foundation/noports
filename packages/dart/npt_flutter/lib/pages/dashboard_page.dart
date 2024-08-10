import 'package:flutter/material.dart';
import 'package:npt_flutter/profile_list/profile_list.dart';
import 'package:npt_flutter/routes.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key("DashboardPage-Scaffold"),
      appBar: AppBar(
        title: const Text("Connections"),
        actions: <Widget>[
          ElevatedButton(
            child: const Text("Settings"),
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pushNamed(Routes.settings);
              }
            },
          ),
        ],
      ),
      body: const ProfileListView(),
    );
  }
}
