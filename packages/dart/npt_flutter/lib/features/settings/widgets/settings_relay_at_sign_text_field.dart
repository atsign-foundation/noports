import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/util/form_validator.dart';

class SettingsRelayAtSignTextField extends StatefulWidget {
  const SettingsRelayAtSignTextField({super.key});

  @override
  State<SettingsRelayAtSignTextField> createState() => _SettingsRelayAtSignTextFieldState();
}

class _SettingsRelayAtSignTextFieldState extends State<SettingsRelayAtSignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, String?>(
      selector: (SettingsState state) {
        if (state is SettingsLoadedState) {
          return state.settings.relayAtsign;
        }
        return null;
      },
      builder: (BuildContext context, String? relayAtsign) {
        if (relayAtsign == null) return const SizedBox();
        controller.text = relayAtsign;
        return TextFormField(
            controller: controller,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormValidator.validateAtsignField,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState).settings.copyWith(relayAtsign: value),
                save: true,
              ));
            });
      },
    );
  }
}
