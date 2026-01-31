import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/widgets/confirmation_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileDeleteButton extends StatelessWidget {
  const ProfileDeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (BuildContext context, ProfileState state) => IconButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: PhosphorIcon(PhosphorIcons.trash()),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ConfirmationDialog(
                message: strings.profileDeleteMessage,
                actionText: strings.delete,
                action: () {
                  App.navState.currentContext?.read<ProfileListBloc>().add(
                    ProfileListDeleteEvent(toDelete: [state.uuid]),
                  );
                },
              );
            },
          );
        },
        // label: Text(strings.delete),
      ),
    );
  }
}
