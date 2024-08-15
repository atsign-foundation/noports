import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/widgets/confirmation_dialog.dart';

class ProfileDeleteButton extends StatelessWidget {
  const ProfileDeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String>(
      selector: (ProfileState state) => state.uuid,
      builder: (BuildContext context, String uuid) => ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ConfirmationDialog(
                  "Are you sure you want to delete this profile?", () {
                App.navState.currentContext
                    ?.read<ProfileListBloc>()
                    .add(ProfileListDeleteEvent(toDelete: [uuid]));
              });
            },
          );
        },
        child: const Text("Delete"),
      ),
    );
  }
}
