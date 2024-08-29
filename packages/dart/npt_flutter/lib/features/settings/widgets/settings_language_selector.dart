import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class SettingsLanguageSelector extends StatelessWidget {
  const SettingsLanguageSelector({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, Language?>(selector: (state) {
      if (state is SettingsLoadedState) {
        return state.settings.language;
      }
      return null;
    }, builder: (context, language) {
      if (language == null) return const Spinner();
      return Column(
        children: [
          Row(
            children: [
              // Text(PreferredViewLayout.minimal.displayName),
              // gapW20,
              DropdownMenu<Language>(
                initialSelection: language,
                dropdownMenuEntries: Language.values
                    .map<DropdownMenuEntry<Language>>(
                      (Language l) => DropdownMenuEntry(
                        value: l,
                        label: l.name,
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  var bloc = context.read<SettingsBloc>();
                  bloc.add(SettingsEditEvent(
                    settings: (bloc.state as SettingsLoadedState).settings.copyWith(language: value),
                    save: true,
                  ));
                },
              ),
            ],
          ),
        ],
      );
    });
  }
}

var a = [1, 2, 3, 4, 5].map((e) => e * 2).toList();
