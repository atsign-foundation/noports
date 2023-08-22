import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

import '../../utils/sizes.dart';

class SSHNPResultAlertDialog extends ConsumerWidget {
  const SSHNPResultAlertDialog({required this.sshnpResult, super.key});
  final SSHNPResult sshnpResult;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final strings = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Center(
        child: AlertDialog(
          title: Text(strings.result),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.success),
              gapH12,
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: sshnpResult.toString(),
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.okButton,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}
