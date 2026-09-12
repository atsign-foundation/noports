import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/health/health_checks.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/custom_snack_bar.dart';
import 'package:noports_config/widgets/section_card.dart';

/// The Diagnostics tab.
class HealthView extends StatelessWidget {
  const HealthView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return BlocBuilder<HealthCubit, HealthState>(
      builder: (context, state) {
        final cubit = context.read<HealthCubit>();
        return ListView(
          padding: const EdgeInsets.all(Sizes.p32),
          children: [
            SectionCard(
              title: strings.healthTitle,
              subtitle: strings.healthSubtitle,
              trailing: state.results.isEmpty
                  ? null
                  : Text(
                      strings.checksSummary(
                        state.count(CheckLevel.pass),
                        state.count(CheckLevel.warn),
                        state.count(CheckLevel.fail),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: state.running ? null : cubit.run,
                        icon: state.running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.health_and_safety_outlined),
                        label: Text(strings.runChecks),
                      ),
                      gapW8,
                      OutlinedButton.icon(
                        onPressed: state.doctorRunning ? null : cubit.runDoctor,
                        icon: state.doctorRunning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.medical_services_outlined),
                        label: Text(strings.runFullDoctor),
                      ),
                    ],
                  ),
                  if (state.results.isNotEmpty) ...[
                    gapH16,
                    HealthResultsList(results: state.results),
                  ],
                  if (state.error != null) ...[
                    gapH12,
                    Text(
                      strings.doctorFailed(state.error!),
                      style: const TextStyle(color: AppColor.errorColor),
                    ),
                  ],
                ],
              ),
            ),
            if (state.doctorOutput != null) ...[
              gapH16,
              SectionCard(
                title: strings.doctorOutput,
                trailing: IconButton(
                  tooltip: strings.copy,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: state.doctorOutput!));
                    if (context.mounted) CustomSnackBar.info(context, strings.copied);
                  },
                ),
                child: LogPanel(text: state.doctorOutput!, height: 420),
              ),
            ],
          ],
        );
      },
    );
  }
}

class HealthResultsList extends StatelessWidget {
  const HealthResultsList({super.key, required this.results});
  final List<HealthResult> results;

  @override
  Widget build(BuildContext context) {
    return InsetPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ResultRow(result: results[i]),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});
  final HealthResult result;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final (icon, color, label) = switch (result.level) {
      CheckLevel.pass => (Icons.check_circle, const Color(0xFF3E7D1F), strings.checkPass),
      CheckLevel.warn => (Icons.warning_amber_rounded, AppColor.warningColor, strings.checkWarn),
      CheckLevel.fail => (Icons.error, AppColor.errorColor, strings.checkFail),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p16, vertical: Sizes.p12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          gapW12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                gapH4,
                SelectableText(
                  result.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          gapW12,
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
