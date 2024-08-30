import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/settings/settings.dart';

class SettingsRelayQuickButtons extends StatelessWidget {
  const SettingsRelayQuickButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, String?>(
        selector: (SettingsState state) {
      if (state is SettingsLoadedState) {
        return state.settings.relayAtsign;
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
                  var bloc = context.read<SettingsBloc>();
                  bloc.add(SettingsEditEvent(
                    settings: (bloc.state as SettingsLoadedState)
                        .settings
                        .copyWith(relayAtsign: value),
                    save: true,
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
