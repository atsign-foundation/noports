import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/widgets/confirmation_dialog.dart';

class ProfileSelectedDeleteButton extends StatelessWidget {
  const ProfileSelectedDeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState,
        Set<String>>(
      selector: (ProfilesSelectedState state) {
        return state.selected;
      },
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if nothing is selected
        if (selected.isEmpty) return const SizedBox();
        return ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) => ConfirmationDialog(
                  "Are you sure you want to delete the selected profiles?", () {
                App.navState.currentContext
                    ?.read<ProfilesSelectedCubit>()
                    .deselectAll();
                App.navState.currentContext
                    ?.read<ProfileListBloc>()
                    .add(ProfileListDeleteEvent(toDelete: selected));
              }),
            );
          },
          child: const Text("Deleted Selected"),
        );
      },
    );
  }
}
