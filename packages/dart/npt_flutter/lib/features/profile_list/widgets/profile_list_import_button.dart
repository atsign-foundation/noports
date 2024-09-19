import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../styles/sizes.dart';
import '../cubit/profiles_selected_cubit.dart';

class ProfileListImportButton extends StatelessWidget {
  const ProfileListImportButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, Set<String>>(
        selector: (state) => state.selected,
        builder: (BuildContext context, Set<String> selected) {
          // Hide this button if something is selected
          if (selected.isNotEmpty) return gap0;
          return ElevatedButton.icon(
            onPressed: Export.importProfiles,
            label: Text(strings.import),
            icon: PhosphorIcon(
              PhosphorIcons.downloadSimple(),
            ),
          );
        });
  }
}
