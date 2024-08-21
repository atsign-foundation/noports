import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class SettingsViewLayoutSelector extends StatelessWidget {
  const SettingsViewLayoutSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
        selector: (state) {
      if (state is SettingsLoadedState) {
        return state.settings.viewLayout;
      }
      return null;
    }, builder: (context, viewLayout) {
      if (viewLayout == null) return const Spinner();
      return Column(
        children: PreferredViewLayout.values
            .map((e) => RadioListTile<PreferredViewLayout>(
                  title: Text(e.displayName),
                  value: e,
                  groupValue: viewLayout,
                  onChanged: (value) {
                    var bloc = context.read<SettingsBloc>();
                    bloc.add(SettingsEditEvent(
                      settings: (bloc.state as SettingsLoadedState)
                          .settings
                          .copyWith(viewLayout: value),
                      save: true,
                    ));
                  },
                ))
            .toList(),
      );
    });
  }
}
