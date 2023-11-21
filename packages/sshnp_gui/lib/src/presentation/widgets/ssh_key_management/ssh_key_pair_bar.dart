import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/controllers/ssh_key_pair_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/ssh_key_management/ssh_key_pair_bar_actions.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

class SshKeyPairBar extends ConsumerStatefulWidget {
  final String identifier;
  const SshKeyPairBar(this.identifier, {Key? key}) : super(key: key);

  @override
  ConsumerState<SshKeyPairBar> createState() => _SskKeyPairBarState();
}

class _SskKeyPairBarState extends ConsumerState<SshKeyPairBar> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final controller = ref.watch(atSSHKeyPairManagerFamilyController(widget.identifier));
    return controller.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) {
        log(error.toString());
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.identifier),
            gapW8,
            Expanded(child: Container()),
            Text(strings.corruptedPrivateKey),
            // ProfileDeleteAction(widget.identifier),
          ],
        );
      },
      data: (atSshKeyPairManager) => Card(
        color: kSshKeyManagementBarColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              atSshKeyPairManager.nickname,
            ),
            SshKeyPairBarActions(
              identifier: widget.identifier,
            ),
          ],
        ),
      ),
    );
  }
}
