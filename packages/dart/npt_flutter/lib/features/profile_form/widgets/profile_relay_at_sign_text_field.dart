import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileRelayAtSignTextField extends StatefulWidget {
  const ProfileRelayAtSignTextField({super.key});

  @override
  State<ProfileRelayAtSignTextField> createState() =>
      _ProfileRelayAtSignTextFieldState();
}

class _ProfileRelayAtSignTextFieldState
    extends State<ProfileRelayAtSignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 200, child: Text("Relay atSign")),
        Expanded(
          child: BlocSelector<ProfileBloc, ProfileState, String?>(
            selector: (ProfileState state) {
              if (state is ProfileLoadedState) {
                return state.profile.relayAtsign;
              }
              return null;
            },
            builder: (BuildContext context, String? relayAtsign) {
              if (relayAtsign == null) return const SizedBox();
              controller.text = relayAtsign;
              return Column(children: [
                TextFormField(
                    controller: controller,
                    onChanged: (value) {
                      var bloc = context.read<ProfileBloc>();
                      bloc.add(ProfileEditEvent(
                        profile: (bloc.state as ProfileLoadedState)
                            .profile
                            .copyWith(relayAtsign: value),
                        save: false,
                      ));
                    }),
              ]);
            },
          ),
        ),
      ],
    );
  }
}
