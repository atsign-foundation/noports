import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/home_wrapper_widget.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/pages/profile_form_page.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/uuid.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../cubit/profiles_selected_cubit.dart';

class ProfileListAddButton extends StatelessWidget {
  const ProfileListAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<
      ProfilesSelectedCubit,
      ProfilesSelectedState,
      Set<String>
    >(
      selector: (ProfilesSelectedState state) => state.selected,
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if something is selected
        if (selected.isNotEmpty) return gap0;
        return ElevatedButton.icon(
          onPressed: () {
            final uuid = Uuid.generate();
            if (context.mounted) {
              wrapperNav.currentState!.pushNamed(
                HomeRoutes.profileForm,
                arguments: ProfileFormPageArguments(uuid),
              );
            }
          },
          label: Text(strings.addNew),
          icon: PhosphorIcon(PhosphorIcons.plusSquare()),
        );
      },
    );
  }
}
