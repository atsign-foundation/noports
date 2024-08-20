import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';

class ProfileSelectBox extends StatelessWidget {
  const ProfileSelectBox({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String>(
      selector: (ProfileState state) {
        return state.uuid;
      },
      builder: (BuildContext context, String uuid) {
        return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, bool>(
          selector: (ProfilesSelectedState state) {
            return state.selected.contains(uuid);
          },
          builder: (BuildContext context, bool checked) {
            return Checkbox(
              value: checked,
              onChanged: (bool? value) {
                switch (value) {
                  case null:
                    return;
                  case true:
                    context.read<ProfilesSelectedCubit>().select(uuid);
                  case false:
                    context.read<ProfilesSelectedCubit>().deselect(uuid);
                }
              },
            );
          },
        );
      },
    );
  }
}
