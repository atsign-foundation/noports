import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileStatusIndicator extends StatelessWidget {
  const ProfileStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: BlocBuilder<ProfileBloc, ProfileState>(builder: (BuildContext context, ProfileState state) {
          if (state is ProfileFailedSave) {
            return Tooltip(message: strings.profileFailedSaveMessage, child: Text(strings.failed));
          }

          if (state is ProfileFailedStart) {
            return Tooltip(message: state.reason ?? strings.profileFailedUnknownMessage, child: Text(strings.failed));
          }

          if (state is ProfileStarting && state.status != null) {
            return Text(state.status!);
          }

          return gap0;
        }),
      ),
    );
  }
}
