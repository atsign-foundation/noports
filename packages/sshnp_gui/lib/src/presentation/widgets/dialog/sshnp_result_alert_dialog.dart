import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/nav_index_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

class SSHNPResultAlertDialog extends ConsumerWidget {
  const SSHNPResultAlertDialog({required this.result, required this.title, super.key});

  final String result;
  final String title;

  void copyToClipBoard({
    required BuildContext context,
    required String clipboardSuccessText,
  }) {
    Clipboard.setData(ClipboardData(text: result)).then((value) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clipboardSuccessText),
          ),
        ));
  }

  void ssh({
    required WidgetRef ref,
    required BuildContext context,
  }) {
    ref.read(navIndexProvider.notifier).goTo(AppRoute.terminal);
    ref.read(terminalSSHCommandProvider.notifier).update((state) => result);
    context.pushReplacementNamed(AppRoute.terminal.name);
  }

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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Center(child: Text(title))),
              result.contains('ssh')
                  ? IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => copyToClipBoard(
                        context: context,
                        clipboardSuccessText: strings.copiedToClipboard,
                      ),
                    )
                  : const SizedBox.shrink()
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: result,
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
              child: Text(strings.closeButton,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
            ),
            result.contains('ssh')
                ? OutlinedButton(
                    onPressed: () => ssh(context: context, ref: ref),
                    child: Text(strings.sshButton,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
