import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/routes.dart';

class ProfileEditButton extends StatelessWidget {
  const ProfileEditButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String>(
      selector: (ProfileState state) => state.uuid,
      builder: (BuildContext context, String uuid) => ElevatedButton(
        onPressed: () {
          if (context.mounted) {
            Navigator.of(context)
                .pushNamed(Routes.profileForm, arguments: uuid);
          }
        },
        child: const Text("Edit"),
      ),
    );
  }
}
