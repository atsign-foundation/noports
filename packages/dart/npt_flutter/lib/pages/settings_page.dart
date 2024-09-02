import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NptAppBar(
        title: strings.settings,
        settingsSelectedColor: AppColor.primaryColor,
      ),
      body: const SettingsView(),
    );
  }
}
