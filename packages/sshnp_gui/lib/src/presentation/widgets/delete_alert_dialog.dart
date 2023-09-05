import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';

import '../../utils/sizes.dart';

class DeleteAlertDialog extends ConsumerWidget {
  const DeleteAlertDialog({required this.sshnpParams, super.key});
  final SSHNPParams sshnpParams;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final strings = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(left: 0),
      child: Center(
        child: AlertDialog(
          title: Center(child: Text(strings.warning)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.warningMessage),
              gapH12,
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: strings.note,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: strings.noteMessage,
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancelButton,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(decoration: TextDecoration.underline)),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(paramsFamilyController(sshnpParams.profileName!))
                    .whenData(
                  (value) async {
                    await value.deleteFile();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              },
              style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
                    backgroundColor: MaterialStateProperty.all(Colors.black),
                  ),
              child: Text(
                strings.deleteButton,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}
