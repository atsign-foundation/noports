import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/widgets/custom_container.dart';

import '../../../styles/sizes.dart';

class SettingsRelayQuickButtons extends StatelessWidget {
  const SettingsRelayQuickButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController controller = ScrollController();
    return BlocSelector<SettingsBloc, SettingsState, String?>(selector: (SettingsState state) {
      if (state is SettingsLoadedState) {
        return state.settings.relayAtsign;
      }
      return null;
    }, builder: (BuildContext context, String? relayAtsign) {
      if (relayAtsign == null) return const SizedBox();
      return Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: Container(
          padding: const EdgeInsets.only(bottom: Sizes.p20),
          height: Sizes.p70,
          child: ListView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            children: [
              ...Constants.defaultRelayOptions.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: Sizes.p10),
                  child: CustomContainer.foreground(
                    key: Key(e.key),
                    child: SizedBox(
                      width: Sizes.p180,
                      child: RadioListTile(
                        title: Text(e.value),
                        value: e.key,
                        groupValue: relayAtsign,
                        onChanged: (value) {
                          var bloc = context.read<SettingsBloc>();
                          bloc.add(SettingsEditEvent(
                            settings: (bloc.state as SettingsLoadedState).settings.copyWith(relayAtsign: value),
                            save: true,
                          ));
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SettingsRelayAtSignTextField(),
            ],
          ),
        ),
      );
    });
  }
}
