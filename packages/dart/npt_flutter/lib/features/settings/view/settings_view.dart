import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/logging.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsInitial) {
          context.read<SettingsBloc>().add(const SettingsLoadEvent());
        }
        switch (state) {
          case SettingsInitial():
          case SettingsLoading():
            return const Spinner();
          case SettingsLoadedState():
            return const Column(children: [
              SettingsErrorHint(),
              Text("Default Relay"),
              SettingsRelayAtSignTextField(),
              SettingsRelayQuickButtons(),
              SettingsOverrideRelaySwitch(),
              SizedBox(height: 100),
              Text("View Mode"),
              SettingsViewLayoutSelector(),
              Text("Advanced"),
              Row(children: [
                Text("Enable Logging"),
                EnableLogsBox(),
                ExportLogsButton(),
                DebugDumpLogsButton(),
              ]),
            ]);
        }
      },
    );
  }
}
