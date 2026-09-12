import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/keys/cubit/enrollment_cubit.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/styles/app_color.dart';
import 'package:noports_config/styles/sizes.dart';
import 'package:noports_config/widgets/section_card.dart';

class EnrollmentOutcome {
  const EnrollmentOutcome(this.atsign, this.deviceName, this.keysFile);
  final String atsign;
  final String deviceName;
  final File keysFile;
}

/// Modal APKAM enrollment: atSign + device name + passcode, then wait for
/// approval from NoPorts Desktop.
class EnrollmentDialog extends StatelessWidget {
  const EnrollmentDialog({
    super.key,
    required this.rootDomain,
    this.initialAtsign,
    this.initialDeviceName,
  });

  final String rootDomain;
  final String? initialAtsign;
  final String? initialDeviceName;

  static Future<EnrollmentOutcome?> show(
    BuildContext context, {
    required String rootDomain,
    String? initialAtsign,
    String? initialDeviceName,
  }) => showDialog<EnrollmentOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => EnrollmentDialog(
      rootDomain: rootDomain,
      initialAtsign: initialAtsign,
      initialDeviceName: initialDeviceName,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EnrollmentCubit(rootDomain: rootDomain),
      child: _Body(initialAtsign: initialAtsign, initialDeviceName: initialDeviceName),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({this.initialAtsign, this.initialDeviceName});
  final String? initialAtsign;
  final String? initialDeviceName;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final _atsign = TextEditingController(text: widget.initialAtsign ?? '');
  late final _device = TextEditingController(text: widget.initialDeviceName ?? '');
  final _code = TextEditingController();

  @override
  void dispose() {
    _atsign.dispose();
    _device.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit(EnrollmentCubit cubit) => cubit.enroll(
    rawAtsign: _atsign.text,
    deviceName: _device.text,
    passcode: _code.text,
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    return BlocConsumer<EnrollmentCubit, EnrollmentState>(
      listener: (context, state) {
        if (state.step == EnrollmentStep.done && state.keysFile != null) {
          Navigator.of(context).pop(
            EnrollmentOutcome(state.atsign, state.deviceName, state.keysFile!),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<EnrollmentCubit>();
        final editing = !state.busy;
        return AlertDialog(
          title: Text(strings.enrollTitle),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InsetPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.enrollHowTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black87)),
                      gapH4,
                      Text(strings.enrollHowStep1, style: small),
                      Text(strings.enrollHowStep2, style: small),
                      Text(strings.enrollHowStep3, style: small),
                    ],
                  ),
                ),
                gapH16,
                TextField(
                  controller: _atsign,
                  enabled: editing,
                  decoration: InputDecoration(labelText: strings.enterAtsign, hintText: '@mydevice_np'),
                ),
                gapH12,
                TextField(
                  controller: _device,
                  enabled: editing,
                  decoration: InputDecoration(labelText: strings.enrollDeviceName, hintText: 'default'),
                ),
                gapH12,
                TextField(
                  controller: _code,
                  enabled: editing,
                  autofocus: true,
                  decoration: InputDecoration(labelText: strings.enrollPasscode, hintText: strings.enrollPasscodeHint),
                  onSubmitted: (_) => editing ? _submit(cubit) : null,
                ),
                if (state.busy) ...[
                  gapH16,
                  Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      gapW12,
                      Expanded(
                        child: Text(switch (state.step) {
                          EnrollmentStep.submitting => strings.enrollSubmitting,
                          EnrollmentStep.awaitingApproval => strings.enrollAwaitingApproval,
                          _ => strings.enrollCreatingKeys,
                        }),
                      ),
                    ],
                  ),
                  if (state.enrollmentId != null) ...[
                    gapH8,
                    Row(
                      children: [
                        Text(strings.enrollmentId, style: small),
                        gapW8,
                        Expanded(
                          child: SelectableText(
                            state.enrollmentId!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.copy,
                          iconSize: 16,
                          onPressed: () => Clipboard.setData(ClipboardData(text: state.enrollmentId!)),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                  ],
                ],
                if (state.error != null) ...[
                  gapH12,
                  Text(state.error!, style: const TextStyle(color: AppColor.errorColor, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cubit.cancel();
                Navigator.of(context).pop();
              },
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: editing ? () => _submit(cubit) : null,
              child: Text(strings.enroll),
            ),
          ],
        );
      },
    );
  }
}
