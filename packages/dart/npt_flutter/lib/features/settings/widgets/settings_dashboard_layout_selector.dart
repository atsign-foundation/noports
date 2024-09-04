import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/spinner.dart';

import '../../../widgets/custom_card.dart';

class SettingsDashboardLayoutSelector extends StatelessWidget {
  const SettingsDashboardLayoutSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
              Text(getPreferredViewLayoutText(context, PreferredViewLayout.minimal)),
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
              Text(getPreferredViewLayoutText(context, PreferredViewLayout.sshStyle)),
            ],
          ),
          gapH18,
          CustomCard.settingsPreview(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              gapH13,
              Padding(
                padding: const EdgeInsets.only(left: Sizes.p20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(strings.preview),
                ),
              ),
              gapH10,
              viewLayout == PreferredViewLayout.minimal
                  ? SvgPicture.asset('assets/simple.svg')
                  : SvgPicture.asset('assets/advance.svg'),
              gapH16,
            ],
          ))
        ],
      );
    });
  }
}

String getPreferredViewLayoutText(BuildContext context, PreferredViewLayout preferredViewLayout) {
  final strings = AppLocalizations.of(context)!;
  switch (preferredViewLayout) {
    case PreferredViewLayout.minimal:
      return strings.minimal;
    case PreferredViewLayout.sshStyle:
      return strings.sshStyle;
  }
}
