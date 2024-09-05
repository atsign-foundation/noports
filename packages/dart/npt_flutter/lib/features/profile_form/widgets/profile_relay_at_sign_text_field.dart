import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileRelayAtSignTextField extends StatefulWidget {
  const ProfileRelayAtSignTextField({super.key});

  @override
  State<ProfileRelayAtSignTextField> createState() => _ProfileRelayAtSignTextFieldState();
}

class _ProfileRelayAtSignTextFieldState extends State<ProfileRelayAtSignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfileBloc, ProfileState, String?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) {
          return state.profile.relayAtsign;
        }
        return null;
      },
      builder: (BuildContext context, String? relayAtsign) {
        if (relayAtsign == null) return const SizedBox();
        controller.text = relayAtsign;
        return TextFormField(
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty || !value.startsWith('@')) {
                return strings.invalidRelayAtsignMsg;
              }
              return null;
            },
            onChanged: (value) {
              var bloc = context.read<ProfileBloc>();
              bloc.add(ProfileEditEvent(
                profile: (bloc.state as ProfileLoadedState).profile.copyWith(relayAtsign: value),
              ));
            });
      },
    );
  }
}
