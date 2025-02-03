import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/authorisation/view/authorisation_view.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class AuthorisationPage extends StatelessWidget {
  const AuthorisationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NptAppBar(
        title: strings.authorisation,
        settingsSelectedColor: AppColor.primaryColor,
      ),
      body: const AuthorisationView(),
    );
  }
}
