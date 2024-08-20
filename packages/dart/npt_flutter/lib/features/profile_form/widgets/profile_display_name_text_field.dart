import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileDisplayNameTextField extends StatelessWidget {
  const ProfileDisplayNameTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text("Display Name")),
        Expanded(
          child: BlocSelector<ProfileBloc, ProfileState, String?>(
            selector: (ProfileState state) {
              if (state is ProfileLoadedState) return state.profile.displayName;
              return null;
            },
            builder: (BuildContext context, String? state) {
              if (state == null) return const SizedBox();
              return TextFormField(
                  initialValue: state,
                  onChanged: (value) {
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState)
                          .profile
                          .copyWith(displayName: value),
                      save: false,
                    ));
                  });
            },
          ),
        ),
      ],
    );
  }
}
