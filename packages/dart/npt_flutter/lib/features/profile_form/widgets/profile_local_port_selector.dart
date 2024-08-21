import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/util/port.dart';

class ProfileLocalPortSelector extends StatelessWidget {
  const ProfileLocalPortSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text("Local Port")),
        Expanded(
          child: BlocSelector<ProfileBloc, ProfileState, int?>(
            selector: (ProfileState state) {
              if (state is ProfileLoadedState) return state.profile.localPort;
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
                          .copyWith(localPort: Port.fromString(value)),
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
