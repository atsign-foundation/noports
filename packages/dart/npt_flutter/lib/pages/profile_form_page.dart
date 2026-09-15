import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';

class ProfileFormPageArguments {
  final String uuid;
  final Profile? copyFrom;

  /// When set, the saved profile is placed in this folder.
  final String? groupId;
  ProfileFormPageArguments(this.uuid, {this.copyFrom, this.groupId});
}

class ProfileFormPage extends StatelessWidget {
  const ProfileFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as ProfileFormPageArguments;
    return Scaffold(
      body: ProfileFormView(
        args.uuid,
        copyFrom: args.copyFrom,
        groupId: args.groupId,
      ),
    );
  }
}
