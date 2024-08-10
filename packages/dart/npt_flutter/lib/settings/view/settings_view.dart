import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/settings/settings.dart';
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
            return const SettingsFormView(
              key: Key("settings-formview"),
            );
        }
      },
    );
  }
}

class SettingsFormView extends StatelessWidget {
  const SettingsFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BlocSelector<SettingsBloc, SettingsState, bool>(selector: (state) {
        return state is SettingsFailedLoad;
      }, builder: (context, hasError) {
        if (hasError) return const Text("Error loading profile");
        return Container();
      }),
      const Text("Default Relay"),
      BlocSelector<SettingsBloc, SettingsState, Tuple<String, String?>?>(
          selector: (state) {
        if (state is SettingsLoadedState) {
          var t = Tuple<String, String?>();
          t.one = state.settings.defaultRelayAtsign; // radio buttons
          t.two = state.settings.customRelayAtsign; // text box
          return t;
        }
        return null;
      }, builder: (context, tuple) {
        if (tuple == null) return const Spinner();
        return Column(children: [
          RadioListTile(
            title: const Text("Los Angeles"),
            value: "@rv_am",
            groupValue: tuple.one,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState)
                    .settings
                    .copyWith(defaultRelayAtsign: value),
                save: true,
              ));
            },
          ),
          RadioListTile(
            title: const Text("London"),
            value: "@rv_eu",
            groupValue: tuple.one,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState)
                    .settings
                    .copyWith(defaultRelayAtsign: value),
                save: true,
              ));
            },
          ),
          RadioListTile(
            title: const Text("Singapore"),
            value: "@rv_ap",
            groupValue: tuple.one,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState)
                    .settings
                    .copyWith(defaultRelayAtsign: value),
                save: true,
              ));
            },
          ),
          RadioListTile(
            title: const Text("Custom"),
            value: "custom",
            groupValue: tuple.one,
            onChanged: (value) {
              var bloc = context.read<SettingsBloc>();
              bloc.add(SettingsEditEvent(
                settings: (bloc.state as SettingsLoadedState)
                    .settings
                    .copyWith(defaultRelayAtsign: value),
                save: true,
              ));
            },
          ),
          if (tuple.one == 'custom')
            TextFormField(
                initialValue: tuple.two,
                onChanged: (value) {
                  var bloc = context.read<SettingsBloc>();
                  bloc.add(SettingsEditEvent(
                    settings: (bloc.state as SettingsLoadedState)
                        .settings
                        .copyWith(customRelayAtsign: value),
                    save: true,
                  ));
                }),
        ]);
      }),
      BlocSelector<SettingsBloc, SettingsState, bool?>(selector: (state) {
        if (state is SettingsLoadedState) {
          return state.settings.overrideRelay;
        }
        return null;
      }, builder: (context, overrideRelay) {
        if (overrideRelay == null) return const Spinner();
        return SwitchListTile(
          title: const Text("Global Relay Override"),
          value: overrideRelay,
          onChanged: (value) {
            var bloc = context.read<SettingsBloc>();
            bloc.add(SettingsEditEvent(
              settings: (bloc.state as SettingsLoadedState)
                  .settings
                  .copyWith(overrideRelay: value),
              save: true,
            ));
          },
        );
      }),
      const SizedBox(height: 100),
      const Text("View Mode"),
      BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
          selector: (state) {
        if (state is SettingsLoadedState) {
          return state.settings.viewLayout;
        }
        return null;
      }, builder: (context, viewLayout) {
        if (viewLayout == null) return const Spinner();
        return Column(children: [
          RadioListTile<PreferredViewLayout>(
            title: const Text("Simple"),
            value: PreferredViewLayout.minimal,
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
          ),
          RadioListTile<PreferredViewLayout>(
            title: const Text("Advanced"),
            value: PreferredViewLayout.sshStyle,
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
          ),
        ]);
      }),
    ]);
  }
}
