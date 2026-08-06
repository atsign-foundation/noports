import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

/// Lets the user pick one or more atsigns to remove from the local keychain.
///
/// Returns `true` if at least one atsign was removed, `false`/`null`
/// otherwise.
class ResetAtsignDialog extends StatefulWidget {
  const ResetAtsignDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(context: context, builder: (_) => const ResetAtsignDialog());
  }

  @override
  State<ResetAtsignDialog> createState() => _ResetAtsignDialogState();
}

class _ResetAtsignDialogState extends State<ResetAtsignDialog> {
  final KeychainStorage keychainStorage = KeychainStorage();
  List<String>? atsigns;
  final Set<String> selected = {};

  @override
  void initState() {
    super.initState();
    keychainStorage.getAllAtsigns().then((value) {
      if (!mounted) return;
      setState(() => atsigns = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final loadedAtsigns = atsigns;

    return AlertDialog(
      title: Text(strings.removeAtsign),
      content: SizedBox(
        width: 320,
        child: loadedAtsigns == null
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : loadedAtsigns.isEmpty
            ? Text(strings.noAtsignsToRemove)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: Text(strings.selectAll),
                    value: selected.length == loadedAtsigns.length,
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          selected.addAll(loadedAtsigns);
                        } else {
                          selected.clear();
                        }
                      });
                    },
                  ),
                  const Divider(),
                  ...loadedAtsigns.map(
                    (atsign) => CheckboxListTile(
                      title: Text(atsign),
                      value: selected.contains(atsign),
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            selected.add(atsign);
                          } else {
                            selected.remove(atsign);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        if (loadedAtsigns != null && loadedAtsigns.isNotEmpty)
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    for (final atsign in selected) {
                      await keychainStorage.removeAtsignFromKeychain(atsign);
                    }
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
            child: Text(strings.removeAtsign),
          ),
      ],
    );
  }
}
