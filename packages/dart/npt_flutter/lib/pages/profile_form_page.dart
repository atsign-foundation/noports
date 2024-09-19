import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class ProfileFormPage extends StatelessWidget {
  const ProfileFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uuid = ModalRoute.of(context)!.settings.arguments as String;
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NptAppBar(title: strings.addNewProfile),
      body: ProfileFormView(uuid),
    );
  }
}
