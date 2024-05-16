import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/private_key_manager_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/ssh_key_management/ssh_key_pair_bar_actions.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class SshKeyPairBar extends ConsumerStatefulWidget {
  final String identifier;
  const SshKeyPairBar(this.identifier, {super.key});

  @override
  ConsumerState<SshKeyPairBar> createState() => _SskKeyPairBarState();
}

class _SskKeyPairBarState extends ConsumerState<SshKeyPairBar> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final strings = AppLocalizations.of(context)!;
    final controller = ref.watch(privateKeyManagerFamilyController(widget.identifier));

    final bodyMedium = Theme.of(context).textTheme.bodyMedium!;

    return controller.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) {
        log(error.toString());
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.identifier,
              style: bodyMedium.copyWith(
                fontSize: bodyMedium.fontSize!.toFont,
              ),
            ),
            gapW8,
            Expanded(child: Container()),
            Text(
              strings.corruptedPrivateKey,
              style: bodyMedium.copyWith(
                fontSize: bodyMedium.fontSize!.toFont,
              ),
            ),

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
              style: bodyMedium.copyWith(
                fontSize: bodyMedium.fontSize!.toFont,
              ),
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
