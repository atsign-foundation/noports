import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';

class ProfileRelayAtSignTextField extends StatefulWidget {
  const ProfileRelayAtSignTextField({super.key});

  @override
  State<ProfileRelayAtSignTextField> createState() => _ProfileRelayAtSignTextFieldState();
}

class _ProfileRelayAtSignTextFieldState extends State<ProfileRelayAtSignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) {
          return state.profile.relayAtsign;
        }
        return null;
      },
      builder: (BuildContext context, String? relayAtsign) {
        if (relayAtsign == null) return gap0;
        Future.microtask(() => controller.text = relayAtsign);
        return SizedBox(
          width: Sizes.p200,
          height: Sizes.p50,
          child: TextFormField(
              controller: controller,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                errorMaxLines: 2,
              ),
              validator: FormValidator.validateAtsignField,
              onChanged: (value) {
                var bloc = context.read<ProfileBloc>();
                bloc.add(ProfileEditEvent(
                  profile: (bloc.state as ProfileLoadedState).profile.copyWith(relayAtsign: value),
                ));
              }),
        );
      },
    );
  }
}
