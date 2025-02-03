import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/util/port.dart';

class ProfileLocalPortSelector extends StatelessWidget {
  const ProfileLocalPortSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.localPort),
        gapH14,
        BlocSelector<ProfileBloc, ProfileState, int?>(
          selector: (ProfileState state) {
            if (state is ProfileLoadedState) return state.profile.localPort;
            return null;
          },
          builder: (BuildContext context, int? state) {
            if (state == null) return gap0;
            return SizedBox(
              height: Sizes.p100,
              child: TextFormField(
                  initialValue: state == 0 ? null : state.toString(),
                  autovalidateMode: AutovalidateMode.always,
                  validator: FormValidator.validateLocalPortField,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: Theme.of(context).textTheme.bodyLarge,
                    errorMaxLines: 2,
                  ),
                  onChanged: (value) {
                    var bloc = context.read<ProfileBloc>();
                    bloc.add(ProfileEditEvent(
                      profile: (bloc.state as ProfileLoadedState).profile.copyWith(localPort: Port.fromString(value)),
                    ));
                  }),
            );
          },
        ),
      ],
    );
  }
}
