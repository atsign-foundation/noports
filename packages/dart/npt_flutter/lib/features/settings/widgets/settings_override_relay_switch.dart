import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class SettingsOverrideRelaySwitch extends StatelessWidget {
  const SettingsOverrideRelaySwitch({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, bool?>(selector: (state) {
      if (state is SettingsLoadedState) {
        return state.settings.overrideRelay;
      }
      return null;
    }, builder: (context, overrideRelay) {
      if (overrideRelay == null) return const Spinner();
      return Row(
        children: [
          Checkbox(
            value: overrideRelay,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState).settings.copyWith(overrideRelay: value),
                save: true,
              ));
            },
          ),
          Text(
            "Override all profiles",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
    });
  }
}
