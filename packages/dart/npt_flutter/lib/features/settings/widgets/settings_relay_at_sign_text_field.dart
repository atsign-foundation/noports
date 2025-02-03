import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/util/general_extensions.dart';

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
        if (relayAtsign == null) return gap0;
        Future.microtask(() => controller.value =
            TextEditingValue(text: relayAtsign, selection: TextSelection.collapsed(offset: relayAtsign.length)));
        return SizedBox(
          width: Sizes.p200,
          height: Sizes.p70,
          child: TextFormField(
              controller: controller,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: FormValidator.validateEmptyRelayField,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.custom,
                errorMaxLines: 2,
              ),
              onChanged: (value) {
                value = value.atsignify();
                controller.value =
                    TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
                var bloc = context.read<SettingsBloc>();
                bloc.add(SettingsEditEvent(
                  settings: (bloc.state as SettingsLoadedState).settings.copyWith(relayAtsign: value),
                  save: true,
                ));
              }),
        );
      },
    );
  }
}
