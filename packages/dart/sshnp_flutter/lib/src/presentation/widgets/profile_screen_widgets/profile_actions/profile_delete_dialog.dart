import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class ProfileDeleteDialog extends ConsumerWidget {
  const ProfileDeleteDialog({required this.profileName, super.key});
  final String profileName;

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
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700),
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
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(decoration: TextDecoration.underline)),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(configFamilyController(profileName).notifier).deleteConfig(context: context);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.black),
                  ),
              child: Text(
                strings.deleteButton,
                style:
                    Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}
