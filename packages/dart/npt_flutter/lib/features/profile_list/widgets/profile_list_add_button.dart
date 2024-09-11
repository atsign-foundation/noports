import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/uuid.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../cubit/profiles_selected_cubit.dart';

class ProfileListAddButton extends StatelessWidget {
  const ProfileListAddButton({
    super.key,
  });

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
              final uuid = Uuid.generate();
              if (context.mounted) {
                Navigator.of(context).pushNamed(Routes.profileForm, arguments: uuid);
              }
            },
            label: Text(strings.addNew),
            icon: PhosphorIcon(
              PhosphorIcons.plusSquare(),
            ),
          );
        });
  }
}
