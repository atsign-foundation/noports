import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/keys/keys_actions.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/custom_snack_bar.dart';
import 'package:noports_config/widgets/section_card.dart';

/// The Keys tab: where the daemon's keys are, enroll to cut new ones, and
/// (for fleets) import an existing file.
class KeysView extends StatelessWidget {
  const KeysView({super.key});

  Future<void> _afterChange(BuildContext context) async {
    // Persist straight away when the config is otherwise complete, so the
    // keys on disk and the file that points at them never disagree.
    final config = context.read<ConfigCubit>();
    if (config.state.problems.isEmpty) {
      final ok = await config.save();
      if (ok && context.mounted) {
        CustomSnackBar.info(context, AppLocalizations.of(context).configSaved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final doc = state.doc;
        final atsign = doc?.atsign;
        final file = KeysRepository().resolve(atsign, doc?.keysFile);
        final exists = file?.existsSync() ?? false;
        return ListView(
          padding: const EdgeInsets.all(Sizes.p32),
          children: [
            SectionCard(
              title: strings.keysTitle,
              subtitle: strings.keysSubtitle,
              trailing: atsign == null
                  ? StatusPill.warning(label: strings.keysNone)
                  : exists
                  ? StatusPill.success(label: strings.keysFound)
                  : StatusPill.error(label: strings.keysMissing),
              child: InsetPanel(
                child: Column(
                  children: [
                    KeyValueRow(label: 'atSign', value: Text(atsign ?? '-')),
                    KeyValueRow(
                      label: strings.enrollDeviceName,
                      value: Text(doc?.deviceName ?? 'default'),
                    ),
                    KeyValueRow(
                      label: strings.keysCurrent,
                      value: SelectableText(file?.path ?? '-'),
                    ),
                    gapH8,
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        gapW8,
                        Expanded(
                          child: Text(
                            strings.keysManagedDir(DaemonPaths.instance.keysDir.path),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            gapH16,
            SectionCard(
              title: strings.enrollCardTitle,
              subtitle: strings.enrollCardBody,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final a = await KeysActions.enroll(context);
                      if (a != null && context.mounted) await _afterChange(context);
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(strings.enrollTitle),
                  ),
                  gapW16,
                  Expanded(
                    child: Text(
                      strings.enrollHowStep1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            gapH16,
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColor.warningColor),
                gapW8,
                Expanded(
                  child: Text(strings.backupKeysReminder,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final a = await KeysActions.importKeys(context);
                    if (a != null && context.mounted) await _afterChange(context);
                  },
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: Text(strings.importKeys),
                ),
              ],
            ),
            gapH4,
            Padding(
              padding: const EdgeInsets.only(left: Sizes.p32),
              child: Text(
                strings.importKeysHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.onSurfaceColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
