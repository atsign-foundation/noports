import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/pages/nav_cubit.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/custom_snack_bar.dart';
import 'package:noports_config/widgets/section_card.dart';

/// The Status tab: live service state, controls and the recent log.
class ServiceView extends StatelessWidget {
  const ServiceView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return BlocConsumer<ServiceCubit, ServiceCubitState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) =>
          CustomSnackBar.error(context, strings.serviceActionFailed(state.error!)),
      builder: (context, state) {
        final status = state.status;
        return ListView(
          padding: const EdgeInsets.all(Sizes.p32),
          children: [
            if (state.elevated == false) ...[
              const _ElevationBanner(),
              gapH16,
            ],
            _ServiceCard(state: state),
            gapH16,
            if (status != null && !status.isInstalled) ...[
              InsetPanel(child: Text(strings.serviceNotInstalledBody)),
              gapH16,
            ],
            _LogCard(state: state),
          ],
        );
      },
    );
  }
}

class _ElevationBanner extends StatelessWidget {
  const _ElevationBanner();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(Sizes.p16),
      decoration: BoxDecoration(
        color: AppColor.warningColorAlt,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColor.warningColor),
          gapW12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.notElevatedTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                gapH4,
                Text(strings.notElevatedBody,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.state});
  final ServiceCubitState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ServiceCubit>();
    final status = state.status;
    final config = context.watch<ConfigCubit>().state;
    final canControl =
        state.elevated != false && (status?.isInstalled ?? false) && !state.isBusy;

    return SectionCard(
      title: strings.serviceTitle,
      subtitle: strings.serviceSubtitle,
      trailing: _statePill(strings, status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: canControl && !(status?.isRunning ?? false)
                    ? cubit.start
                    : null,
                icon: state.busy == ServiceAction.start
                    ? const _Busy()
                    : const Icon(Icons.play_arrow),
                label: Text(strings.start),
              ),
              gapW8,
              OutlinedButton.icon(
                onPressed: canControl && (status?.isRunning ?? false)
                    ? cubit.stop
                    : null,
                icon: state.busy == ServiceAction.stop
                    ? const _Busy()
                    : const Icon(Icons.stop),
                label: Text(strings.stop),
              ),
              gapW8,
              OutlinedButton.icon(
                onPressed: canControl ? cubit.restart : null,
                icon: state.busy == ServiceAction.restart
                    ? const _Busy()
                    : const Icon(Icons.refresh),
                label: Text(strings.restart),
              ),
              const Spacer(),
              IconButton(
                tooltip: strings.refresh,
                onPressed: cubit.refresh,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          gapH16,
          InsetPanel(
            child: Column(
              children: [
                KeyValueRow(
                  label: strings.serviceName,
                  value: Text(cubit.manager.serviceName),
                ),
                KeyValueRow(
                  label: strings.startType,
                  value: Text(status?.startType ?? '-'),
                ),
                KeyValueRow(
                  label: strings.processId,
                  value: Text(status?.pid?.toString() ?? '-'),
                ),
                if (status?.exitCode != null)
                  KeyValueRow(
                    label: strings.lastExitCode,
                    value: Text(
                      '${status!.exitCode}',
                      style: const TextStyle(color: AppColor.errorColor),
                    ),
                  ),
                const Divider(height: Sizes.p24),
                _DeviceSummary(config: config),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statePill(AppLocalizations strings, ServiceStatus? status) {
    switch (status?.state) {
      case ServiceState.running:
        return StatusPill.success(label: strings.stateRunning);
      case ServiceState.stopped:
        return StatusPill.warning(label: strings.stateStopped);
      case ServiceState.starting:
        return StatusPill.neutral(label: strings.stateStarting);
      case ServiceState.stopping:
        return StatusPill.neutral(label: strings.stateStopping);
      case ServiceState.notInstalled:
        return StatusPill.error(label: strings.stateNotInstalled);
      case ServiceState.unknown:
      case null:
        return StatusPill.neutral(label: strings.stateUnknown);
    }
  }
}

class _DeviceSummary extends StatelessWidget {
  const _DeviceSummary({required this.config});
  final ConfigState config;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final doc = config.doc;
    if (doc == null || doc.isUnconfigured) {
      return Row(
        children: [
          Expanded(
            child: Text(
              strings.notConfigured,
              style: const TextStyle(color: AppColor.warningColor),
            ),
          ),
          OutlinedButton(
            onPressed: () => context.read<NavCubit>().showWizard(),
            child: Text(strings.runSetup),
          ),
        ],
      );
    }
    final access = <String>[
      if (doc.managers.isNotEmpty) doc.managers.join(', '),
      if (doc.policyManager != null) 'policy ${doc.policyManager}',
    ].join(' + ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.deviceSummary(doc.deviceName ?? 'default', doc.atsign!),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black87,
          ),
        ),
        gapH4,
        Text(
          strings.configuredManagers(access.isEmpty ? '-' : access),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.state});
  final ServiceCubitState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ServiceCubit>();
    return SectionCard(
      title: strings.logsTitle,
      subtitle: strings.logsSource(cubit.manager.logSourceDescription),
      trailing: Row(
        children: [
          IconButton(
            tooltip: strings.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: state.logs));
              if (context.mounted) CustomSnackBar.info(context, strings.copied);
            },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: strings.refresh,
            onPressed: state.loadingLogs ? null : cubit.loadLogs,
            icon: state.loadingLogs ? const _Busy() : const Icon(Icons.sync),
          ),
        ],
      ),
      child: LogPanel(text: state.logs, height: 320),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
