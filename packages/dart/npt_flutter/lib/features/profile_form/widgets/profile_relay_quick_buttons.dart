import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileRelayQuickButtons extends StatelessWidget {
  const ProfileRelayQuickButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String?>(
        selector: (ProfileState state) {
      if (state is ProfileLoadedState) {
        return state.profile.relayAtsign;
      }
      return null;
    }, builder: (BuildContext context, String? relayAtsign) {
      if (relayAtsign == null) return const SizedBox();
      return Row(
        children: [
          const SizedBox(width: 200),
          const Text('Populate Relay atSign with a preset:'),
          ...Constants.defaultRelayOptions.entries.map(
            (e) => SizedBox(
              key: Key(e.key),
              width: 200,
              child: RadioListTile(
                title: Text(e.value),
                value: e.key,
                groupValue: relayAtsign,
                onChanged: (value) {
                  var bloc = context.read<ProfileBloc>();
                  bloc.add(ProfileEditEvent(
                    profile: (bloc.state as ProfileLoadedState)
                        .profile
                        .copyWith(relayAtsign: value),
                  ));
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}
