import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

class ProfileFormPageArguments {
  final String uuid;
  final Profile? copyFrom;
  ProfileFormPageArguments(this.uuid, {this.copyFrom});
}

class ProfileFormPage extends StatelessWidget {
  const ProfileFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as ProfileFormPageArguments;
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NptAppBar(title: strings.addNewProfile),
      body: ProfileFormView(args.uuid, copyFrom: args.copyFrom),
    );
  }
}
