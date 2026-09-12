import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/config/widgets/config_field_widget.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/health/view/health_view.dart';
import 'package:noports_config/features/keys/keys_actions.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/pages/nav_cubit.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/section_card.dart';
import 'package:noports_core/sshnpd.dart';

/// First-run flow shown when sshnpd.yaml has no device atSign yet.
/// Keys -> Access -> Device -> Finish (save, start, check).
class SetupWizardView extends StatefulWidget {
  const SetupWizardView({super.key});

  @override
  State<SetupWizardView> createState() => _SetupWizardViewState();
}

enum _Phase { idle, saving, starting, checking, done }

class _SetupWizardViewState extends State<SetupWizardView> {
  int _step = 0;
  _Phase _phase = _Phase.idle;
  String? _failure;
  bool _startedOk = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final config = context.watch<ConfigCubit>().state;
    final doc = config.doc;
    if (doc == null) return const Center(child: CircularProgressIndicator.adaptive());

    final keysFile = KeysRepository().resolve(doc.atsign, doc.keysFile);
    final keysReady = doc.atsign != null && (keysFile?.existsSync() ?? false);
    final accessReady = doc.managers.isNotEmpty || doc.policyManager != null;
    final deviceReady = doc.validate().every(
      (p) => p.option != SshnpdOption.device &&
          !(p.option == SshnpdOption.atsign && doc.atsign != null),
    );

    final steps = [strings.stepDevice, strings.stepKeys, strings.stepAccess, strings.stepFinish];
    final canNext = switch (_step) {
      0 => deviceReady && doc.atsign != null,
      1 => keysReady,
      2 => accessReady,
      _ => false,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.p960),
        child: Padding(
          padding: const EdgeInsets.all(Sizes.p32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.wizardTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
              gapH8,
              Text(strings.wizardIntro, style: Theme.of(context).textTheme.bodySmall),
              gapH24,
              _StepHeader(steps: steps, current: _step),
              gapH16,
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    0 => _DeviceStep(),
                    1 => _KeysStep(keysReady: keysReady),
                    2 => _AccessStep(),
                    _ => _FinishStep(
                      phase: _phase,
                      failure: _failure,
                      startedOk: _startedOk,
                    ),
                  },
                ),
              ),
              gapH16,
              Row(
                children: [
                  TextButton(
                    onPressed: _phase == _Phase.idle || _phase == _Phase.done
                        ? () => context.read<NavCubit>().dismissWizard()
                        : null,
                    child: Text(strings.skipSetup),
                  ),
                  const Spacer(),
                  if (_step > 0 && _phase == _Phase.idle)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(strings.back),
                    ),
                  gapW8,
                  if (_step < 3)
                    FilledButton(
                      onPressed: canNext ? () => setState(() => _step++) : null,
                      child: Text(strings.next),
                    )
                  else if (_phase == _Phase.done)
                    FilledButton(
                      onPressed: () => context.read<NavCubit>().dismissWizard(
                        goTo: _startedOk ? HomeTab.status : HomeTab.diagnostics,
                      ),
                      child: Text(strings.openDashboard),
                    )
                  else
                    FilledButton(
                      onPressed: _phase == _Phase.idle ? _finish : null,
                      child: Text(strings.finishAndStart),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final config = context.read<ConfigCubit>();
    final service = context.read<ServiceCubit>();
    final health = context.read<HealthCubit>();
    final strings = AppLocalizations.of(context);
    setState(() {
      _failure = null;
      _phase = _Phase.saving;
    });
    final saved = await config.save();
    if (!saved) {
      setState(() {
        _failure = config.state.error ?? config.state.problems.join('\n');
        _phase = _Phase.idle;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.starting);
    var installed = service.state.status?.isInstalled ?? false;
    final legacy = service.state.status?.warning != null;
    if ((!installed || legacy) && service.manager.canInstall) {
      installed = await service.install();
      if (!installed) _failure = service.state.error;
    }
    if (installed) {
      final running = service.state.status?.isRunning ?? false;
      _startedOk = running ? await service.restart() : await service.start();
      if (!_startedOk) _failure = service.state.error;
    } else {
      _startedOk = false;
      _failure = strings.serviceNotInstalledBody;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.checking);
    await health.run();
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.steps, required this.current});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= current ? AppColor.primaryColor : AppColor.dividerColor,
              ),
            ),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColor.primaryColor : Colors.white,
                  border: Border.all(
                    color: i <= current ? AppColor.primaryColor : AppColor.dividerColor,
                    width: 2,
                  ),
                ),
                child: i < current
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i <= current ? Colors.white : AppColor.onSurfaceColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
              ),
              gapW8,
              Text(
                steps[i],
                style: TextStyle(
                  fontWeight: i == current ? FontWeight.w600 : FontWeight.normal,
                  color: i <= current ? Colors.black87 : AppColor.onSurfaceColor,
                ),
              ),
              gapW8,
            ],
          ),
        ],
      ],
    );
  }
}

class _KeysStep extends StatelessWidget {
  const _KeysStep({required this.keysReady});
  final bool keysReady;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final doc = context.watch<ConfigCubit>().state.doc!;
    return SectionCard(
      title: strings.enrollCardTitle,
      subtitle: strings.wizardKeysBody,
      trailing: keysReady ? StatusPill.success(label: strings.wizardKeysReady(doc.atsign!)) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsetPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.enrollHowTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black87)),
                gapH4,
                Text(strings.enrollHowStep1, style: Theme.of(context).textTheme.bodySmall),
                Text(strings.enrollHowStep2, style: Theme.of(context).textTheme.bodySmall),
                Text(strings.enrollHowStep3, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          gapH16,
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => KeysActions.enroll(context),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(strings.enrollTitle),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => KeysActions.importKeys(context),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: Text(strings.importKeys),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ConfigCubit>();
    final doc = context.watch<ConfigCubit>().state.doc!;
    final problems = doc.validate();
    return SectionCard(
      title: strings.stepAccess,
      subtitle: strings.wizardAccessBody,
      child: Column(
        children: [
          for (final o in [SshnpdOption.managers, SshnpdOption.policyManager])
            ConfigFieldWidget(
              field: ConfigSchema.byOption(o),
              value: doc.get(ConfigSchema.byOption(o).path),
              problem: problems
                  .where((p) => p.option == o && !p.message.startsWith('Add at least'))
                  .map((p) => p.message)
                  .join('\n')
                  .let((s) => s.isEmpty ? null : s),
              onChanged: (v) => cubit.setField(ConfigSchema.byOption(o), v),
            ),
        ],
      ),
    );
  }
}

class _DeviceStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ConfigCubit>();
    final doc = context.watch<ConfigCubit>().state.doc!;
    final field = ConfigSchema.byOption(SshnpdOption.device);
    final problems = doc.validate();
    final atsignField = ConfigSchema.byOption(SshnpdOption.atsign);
    return SectionCard(
      title: strings.stepDevice,
      subtitle: strings.wizardDeviceBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConfigFieldWidget(
            field: atsignField,
            value: doc.get(atsignField.path),
            problem: problems
                .where((p) => p.option == SshnpdOption.atsign)
                .map((p) => p.message)
                .join('\n')
                .let((s) => s.isEmpty ? null : s),
            onChanged: (v) => cubit.setField(atsignField, v),
          ),
          ConfigFieldWidget(
            field: field,
            value: doc.get(field.path),
            problem: problems
                .where((p) => p.option == SshnpdOption.device)
                .map((p) => p.message)
                .join('\n')
                .let((s) => s.isEmpty ? null : s),
            onChanged: (v) => cubit.setField(field, v),
          ),
          TextButton.icon(
            onPressed: () {
              final host = Platform.localHostname
                  .split('.')
                  .first
                  .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
              cubit.setField(field, host);
            },
            icon: const Icon(Icons.computer_outlined, size: 16),
            label: Text(strings.hostname),
          ),
        ],
      ),
    );
  }
}

class _FinishStep extends StatelessWidget {
  const _FinishStep({required this.phase, required this.failure, required this.startedOk});
  final _Phase phase;
  final String? failure;
  final bool startedOk;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final doc = context.watch<ConfigCubit>().state.doc!;
    final health = context.watch<HealthCubit>().state;
    return SectionCard(
      title: strings.stepFinish,
      subtitle: strings.wizardFinishBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsetPanel(
            child: Column(
              children: [
                KeyValueRow(label: strings.stepKeys, value: Text(doc.atsign ?? '-')),
                KeyValueRow(
                  label: strings.stepAccess,
                  value: Text([
                    ...doc.managers,
                    if (doc.policyManager != null) 'policy ${doc.policyManager}',
                  ].join(', ')),
                ),
                KeyValueRow(label: strings.stepDevice, value: Text(doc.deviceName ?? 'default')),
              ],
            ),
          ),
          if (phase != _Phase.idle) ...[
            gapH16,
            _PhaseRow(label: strings.wizardSaving, active: phase == _Phase.saving, done: phase.index > _Phase.saving.index),
            _PhaseRow(label: strings.wizardStarting, active: phase == _Phase.starting, done: phase.index > _Phase.starting.index, failed: phase.index > _Phase.starting.index && !startedOk),
            _PhaseRow(label: strings.wizardChecking, active: phase == _Phase.checking, done: phase == _Phase.done),
          ],
          if (failure != null) ...[
            gapH12,
            Text(failure!, style: const TextStyle(color: AppColor.errorColor, fontSize: 12)),
          ],
          if (phase == _Phase.done) ...[
            gapH16,
            Text(
              health.allPassed && startedOk ? strings.wizardComplete : strings.wizardCompleteWithIssues,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            ),
            gapH12,
            HealthResultsList(results: health.results),
          ],
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.label, required this.active, required this.done, this.failed = false});
  final String label;
  final bool active;
  final bool done;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sizes.p4),
      child: Row(
        children: [
          if (active)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (failed)
            const Icon(Icons.error, size: 18, color: AppColor.errorColor)
          else if (done)
            const Icon(Icons.check_circle, size: 18, color: Color(0xFF3E7D1F))
          else
            const Icon(Icons.circle_outlined, size: 18, color: AppColor.dividerColor),
          gapW8,
          Text(label),
        ],
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
