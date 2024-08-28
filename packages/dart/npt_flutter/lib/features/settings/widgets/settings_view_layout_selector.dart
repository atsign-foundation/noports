import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class SettingsViewLayoutSelector extends StatelessWidget {
  const SettingsViewLayoutSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(selector: (state) {
      if (state is SettingsLoadedState) {
        return state.settings.viewLayout;
      }
      return null;
    }, builder: (context, viewLayout) {
      if (viewLayout == null) return const Spinner();
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(PreferredViewLayout.minimal.displayName),
              gapW20,
              Switch(
                value: viewLayout == PreferredViewLayout.minimal ? false : true,
                onChanged: (value) {
                  var bloc = context.read<SettingsBloc>();
                  bloc.add(SettingsEditEvent(
                    settings: (bloc.state as SettingsLoadedState).settings.copyWith(
                        viewLayout: value == false ? PreferredViewLayout.minimal : PreferredViewLayout.sshStyle),
                    save: true,
                  ));
                },
              ),
              gapW20,
              Text(PreferredViewLayout.sshStyle.displayName),
            ],
          ),
          gapH18,
          viewLayout == PreferredViewLayout.minimal
              ? SvgPicture.asset('assets/advance_preview.svg')
              : SvgPicture.asset('assets/advance_preview.svg'),
        ],
      );
    });
  }
}
