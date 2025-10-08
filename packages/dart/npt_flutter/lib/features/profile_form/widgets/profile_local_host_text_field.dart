import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ProfileLocalHostTextField extends StatelessWidget {
  const ProfileLocalHostTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.localHost),
        gapH4,
        Text(
          strings.localHostDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        gapH14,
        BlocSelector<ProfileBloc, ProfileState, String>(
          selector: (ProfileState state) {
            if (state is ProfileLoadedState) return state.profile.localHost;
            return StringConst.localhost;
          },
          builder: (BuildContext context, String state) {
            // If state is null, it is set to the default value of 'localhost'.
            // This prevents the TextFormField from being empty initially for profile created before localHost was field was added.

            // state ??= StringConst.localhost;
            return SizedBox(
              height: Sizes.p100,
              width: Sizes.p300,
              child: TextFormField(
                initialValue: state,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: FormValidator.validateHostField,
                decoration: const InputDecoration(errorMaxLines: 3),
                onChanged: (value) {
                  var bloc = context.read<ProfileBloc>();
                  bloc.add(
                    ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState).profile
                          .copyWith(localHost: value),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
