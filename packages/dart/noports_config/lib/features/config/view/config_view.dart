import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/config/widgets/config_field_widget.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/custom_snack_bar.dart';
import 'package:noports_config/widgets/section_card.dart';

/// The Configuration tab: a form generated from [ConfigSchema] and a raw
/// YAML editor over the same document.
class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  bool _yamlMode = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        if (state.status == ConfigStatus.loading ||
            state.status == ConfigStatus.initial) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (state.status == ConfigStatus.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.configLoadFailed(state.error ?? '')),
                gapH16,
                OutlinedButton(
                  onPressed: () => context.read<ConfigCubit>().load(),
                  child: Text(strings.retry),
                ),
              ],
            ),
          );
        }
        final cubit = context.read<ConfigCubit>();
        final problems = state.problems;
        final path = cubit.repository.file.path;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.p32,
                Sizes.p24,
                Sizes.p32,
                Sizes.p12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              strings.configTitle,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.black87),
                            ),
                            gapW12,
                            if (state.isDirty)
                              StatusPill.warning(label: strings.unsavedChanges),
                          ],
                        ),
                        gapH4,
                        Text(
                          strings.configFile(path),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColor.onSurfaceColor,
                          ),
                        ),
                        if (!state.existed)
                          Text(
                            strings.configMissingNote,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColor.warningColor),
                          ),
                      ],
                    ),
                  ),
                  if (!_yamlMode) ...[
                    Text(strings.showAdvanced,
                        style: Theme.of(context).textTheme.bodySmall),
                    Switch(
                      value: state.showAdvanced,
                      onChanged: cubit.toggleAdvanced,
                    ),
                    gapW16,
                  ],
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(strings.formTab)),
                      ButtonSegment(value: true, label: Text(strings.yamlTab)),
                    ],
                    selected: {_yamlMode},
                    onSelectionChanged: (s) =>
                        setState(() => _yamlMode = s.first),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _yamlMode
                  ? _YamlEditor(state: state)
                  : _FormEditor(state: state, problems: problems),
            ),
            _ActionBar(state: state, problems: problems),
          ],
        );
      },
    );
  }
}

class _FormEditor extends StatelessWidget {
  const _FormEditor({required this.state, required this.problems});
  final ConfigState state;
  final List problems;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConfigCubit>();
    final doc = state.doc!;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p32,
        vertical: Sizes.p12,
      ),
      children: [
        for (final section in ConfigSection.values)
          if (ConfigSchema.inSection(section)
              .any((f) => !f.advanced || state.showAdvanced)) ...[
            SectionCard(
              title: section.title,
              child: Column(
                children: [
                  for (final field in ConfigSchema.inSection(section))
                    if (!field.advanced || state.showAdvanced)
                      ConfigFieldWidget(
                        key: ValueKey(field.option),
                        field: field,
                        value: doc.get(field.path),
                        problem: problems
                            .where((p) => p.option == field.option)
                            .map((p) => p.message as String)
                            .join('\n')
                            .let((s) => s.isEmpty ? null : s),
                        onChanged: (v) => cubit.setField(field, v),
                      ),
                ],
              ),
            ),
            gapH16,
          ],
      ],
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _YamlEditor extends StatefulWidget {
  const _YamlEditor({required this.state});
  final ConfigState state;

  @override
  State<_YamlEditor> createState() => _YamlEditorState();
}

class _YamlEditorState extends State<_YamlEditor> {
  late final TextEditingController _c =
      TextEditingController(text: widget.state.source);

  @override
  void didUpdateWidget(covariant _YamlEditor old) {
    super.didUpdateWidget(old);
    // Follow external changes (revert, import) but never clobber text the
    // user is in the middle of fixing.
    if (widget.state.yamlError == null && widget.state.source != _c.text) {
      _c.text = widget.state.source;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p32,
        vertical: Sizes.p12,
      ),
      child: Column(
        children: [
          if (widget.state.yamlError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: Sizes.p8),
              padding: const EdgeInsets.all(Sizes.p12),
              decoration: BoxDecoration(
                color: AppColor.errorColorAlt,
                borderRadius: BorderRadius.circular(Sizes.p10),
              ),
              child: Text(
                strings.yamlInvalid(widget.state.yamlError!),
                style: const TextStyle(color: AppColor.errorColor, fontSize: 12),
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Sizes.p16),
              ),
              padding: const EdgeInsets.all(Sizes.p16),
              child: TextField(
                controller: _c,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: context.read<ConfigCubit>().replaceYaml,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.problems});
  final ConfigState state;
  final List problems;

  Future<void> _save(BuildContext context, {bool restart = false}) async {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ConfigCubit>();
    if (problems.isNotEmpty) {
      CustomSnackBar.error(context, strings.fixProblemsBeforeSaving);
      return;
    }
    final ok = await cubit.save();
    if (!context.mounted) return;
    if (!ok) {
      CustomSnackBar.error(
        context,
        strings.configSaveFailed(cubit.state.error ?? ''),
      );
      return;
    }
    if (!restart) {
      CustomSnackBar.success(context, strings.configSaved);
      return;
    }
    final service = context.read<ServiceCubit>();
    final running = service.state.status?.isRunning ?? false;
    final restarted = running ? await service.restart() : await service.start();
    if (!context.mounted) return;
    if (restarted) {
      CustomSnackBar.success(context, strings.serviceRestarted);
    } else {
      CustomSnackBar.error(
        context,
        strings.serviceActionFailed(service.state.error ?? ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final cubit = context.read<ConfigCubit>();
    final serviceState = context.watch<ServiceCubit>().state;
    final canControl = serviceState.elevated != false &&
        (serviceState.status?.isInstalled ?? false);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p32,
        vertical: Sizes.p16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColor.dividerColorAlt)),
      ),
      child: Row(
        children: [
          Expanded(
            child: problems.isEmpty
                ? Text(
                    strings.restartNeededNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColor.onSurfaceColor,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in problems)
                        Text(
                          '• ${p.message}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColor.errorColor),
                        ),
                    ],
                  ),
          ),
          gapW16,
          OutlinedButton(
            onPressed: state.isDirty ? cubit.revert : null,
            child: Text(strings.revert),
          ),
          gapW8,
          OutlinedButton(
            onPressed: state.saving ||
                    serviceState.elevated == false ||
                    (!state.isDirty && state.existed)
                ? null
                : () => _save(context),
            child: Text(strings.save),
          ),
          gapW8,
          FilledButton(
            onPressed: state.saving || !canControl || serviceState.isBusy
                ? null
                : () => _save(context, restart: true),
            child: Text(strings.saveAndRestart),
          ),
        ],
      ),
    );
  }
}
