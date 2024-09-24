import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ProfileDisplayNameTextField extends StatelessWidget {
  const ProfileDisplayNameTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.profileName),
          gapH4,
          Text(
            strings.profileNameDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          gapH10,
          BlocSelector<ProfileBloc, ProfileState, String?>(
            selector: (ProfileState state) {
              if (state is ProfileLoadedState) return state.profile.displayName;
              return null;
            },
            builder: (BuildContext context, String? state) {
              if (state == null) return gap0;
              return SizedBox(
                width: double.infinity,
                child: TextFormField(
                    initialValue: state,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormValidator.validateProfileNameField,
                    onChanged: (value) {
                      var bloc = context.read<ProfileBloc>();
                      bloc.add(ProfileEditEvent(
                        profile: (bloc.state as ProfileLoadedState).profile.copyWith(displayName: value),
                      ));
                    }),
              );
            },
          ),
        ],
      ),
    );
  }
}
