import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      if (relayAtsign == null) return gap0;
      return Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sizes.p10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...RelayOptions.values.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: Sizes.p10, top: Sizes.p4),
                      child: CustomContainer.foreground(
                        key: Key(e.name),
                        child: SizedBox(
                          width: Sizes.p200,
                          child: RadioListTile(
                            title: Text(e.regions),
                            value: e.relayAtsign,
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
                  const Padding(
                    padding: EdgeInsets.only(top: Sizes.p4),
                    child: SettingsRelayAtSignTextField(),
                  ),
                ],
              ),
            )),
      );
    });
  }
}
