import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../styles/sizes.dart';
import '../cubit/profiles_selected_cubit.dart';

class ProfileListRefreshButton extends StatelessWidget {
  final bool useCache;
  const ProfileListRefreshButton({super.key, this.useCache = false});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, Set<String>>(
        selector: (ProfilesSelectedState state) => state.selected,
        builder: (BuildContext context, Set<String> selected) {
          // Hide this button if something is selected
          if (selected.isNotEmpty) return gap0;
          return ElevatedButton.icon(
              onPressed: () {
                context.read<ProfileListBloc>().add(const ProfileListLoadEvent());
              },
              label: Text(strings.refresh),
              icon: PhosphorIcon(
                PhosphorIcons.arrowClockwise(),
              ));
        });
  }
}
