import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/form_validator.dart';

class SettingsRelayAtsignTextField extends StatefulWidget {
  const SettingsRelayAtsignTextField({super.key});

  @override
  State<SettingsRelayAtsignTextField> createState() =>
      _SettingsRelayAtsignTextFieldState();
}

class _SettingsRelayAtsignTextFieldState
    extends State<SettingsRelayAtsignTextField> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, Atsign?>(
      selector: (SettingsState state) {
        if (state is SettingsLoadedState) {
          return state.settings.relayAtsign;
        }
        return null;
      },
      builder: (BuildContext context, Atsign? relayAtsign) {
        if (relayAtsign == null) return gap0;
        Future.microtask(
          () => controller.value = TextEditingValue(
            text: relayAtsign,
            selection: TextSelection.collapsed(offset: relayAtsign.length),
          ),
        );
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
              value = value.toAtsign();
              controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
              var bloc = context.read<SettingsBloc>();
              bloc.add(
                SettingsEditEvent(
                  settings: (bloc.state as SettingsLoadedState).settings
                      .copyWith(relayAtsign: value.toAtsign()),
                  save: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
