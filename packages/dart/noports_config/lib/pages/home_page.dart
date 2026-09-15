import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/view/config_view.dart';
import 'package:noports_config/features/health/view/health_view.dart';
import 'package:noports_config/features/keys/view/keys_view.dart';
import 'package:noports_config/features/service/view/service_view.dart';
import 'package:noports_config/features/wizard/view/setup_wizard_view.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/pages/nav_cubit.dart';
import 'package:noports_config/widgets/config_app_bar.dart';

/// App shell: top bar with tabs, or the setup wizard on first run.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final nav = context.watch<NavCubit>().state;
    final config = context.watch<ConfigCubit>().state;

    // Decide once, when the config has loaded, whether to start in the
    // wizard. Afterwards only explicit navigation changes it.
    if (!nav.decided && config.status == ConfigStatus.ready) {
      final navCubit = context.read<NavCubit>();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navCubit.decideInitial(unconfigured: config.isUnconfigured),
      );
    }
    final showWizard = nav.wizard;

    final tabs = [
      strings.tabStatus,
      strings.tabConfiguration,
      strings.tabKeys,
      strings.tabDiagnostics,
    ];
    return Scaffold(
      appBar: ConfigAppBar(
        tabs: tabs,
        selected: showWizard ? -1 : nav.tab.index,
        onSelected: (i) {
          if (showWizard) context.read<NavCubit>().dismissWizard();
          context.read<NavCubit>().select(HomeTab.values[i]);
        },
      ),
      body: !nav.decided
          ? const Center(child: CircularProgressIndicator.adaptive())
          : showWizard
          ? const SetupWizardView()
          : IndexedStack(
              index: nav.tab.index,
              children: const [
                ServiceView(),
                ConfigView(),
                KeysView(),
                HealthView(),
              ],
            ),
    );
  }
}
