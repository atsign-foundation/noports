import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ProfileRemoteHostTextField extends StatelessWidget {
  const ProfileRemoteHostTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.remoteHost),
        gapH4,
        Text(strings.remoteHostDescription, style: Theme.of(context).textTheme.bodySmall),
        gapH10,
        BlocSelector<ProfileBloc, ProfileState, String?>(
          selector: (ProfileState state) {
            if (state is ProfileLoadedState) return state.profile.remoteHost;
            return null;
          },
          builder: (BuildContext context, String? state) {
            if (state == null) return gap0;
            return SizedBox(
              height: Sizes.p100,
              child: TextFormField(
                  initialValue: state,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: FormValidator.validateRemoteHostField,
                  decoration: const InputDecoration(
                    errorMaxLines: 3,
                  ),
                  onChanged: (value) {
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState).profile.copyWith(remoteHost: value),
                    ));
                  }),
            );
          },
        ),
      ],
    );
  }
}
