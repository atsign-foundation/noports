import 'package:flutter/material.dart';
import 'package:npt_flutter/settings/settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key("SettingsPage-Scaffold"),
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: const SettingsView(),
    );
  }
}
