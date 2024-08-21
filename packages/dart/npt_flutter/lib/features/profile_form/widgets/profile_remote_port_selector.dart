import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/util/port.dart';

class ProfileRemotePortSelector extends StatelessWidget {
  const ProfileRemotePortSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text("Remote Port")),
        Expanded(
          child: BlocSelector<ProfileBloc, ProfileState, int?>(
            selector: (ProfileState state) {
              if (state is ProfileLoadedState) return state.profile.remotePort;
              return null;
            },
            builder: (BuildContext context, int? state) {
              if (state == null) return const SizedBox();
              return TextFormField(
                  initialValue: state.toString(),
                  onChanged: (value) {
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState)
                          .profile
                          .copyWith(remotePort: Port.fromString(value)),
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
