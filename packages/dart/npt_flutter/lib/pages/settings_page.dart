import 'package:flutter/material.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: NptAppBar(title: 'Settings', settingsSelectedColor: AppColor.primaryColor),
      body: SettingsView(),
    );
  }
}
