import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/widgets/confirmation_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileSelectedDeleteButton extends StatelessWidget {
  const ProfileSelectedDeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, Set<String>>(
      selector: (ProfilesSelectedState state) {
        return state.selected;
      },
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if nothing is selected
        if (selected.isEmpty) return const SizedBox();
        return ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) => ConfirmationDialog(
                  message: strings.profileDeleteSelectedMessage,
                  actionText: strings.delete,
                  action: () {
                    App.navState.currentContext?.read<ProfilesSelectedCubit>().deselectAll();
                    App.navState.currentContext
                        ?.read<ProfileListBloc>()
                        .add(ProfileListDeleteEvent(toDelete: selected));
                  }),
            );
          },
          label: Text(strings.delete),
          icon: PhosphorIcon(
            PhosphorIcons.trash(),
          ),
        );
      },
    );
  }
}
