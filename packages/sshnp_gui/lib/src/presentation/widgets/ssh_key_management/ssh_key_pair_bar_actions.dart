import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';

import '../../../controllers/ssh_key_pair_controller.dart';
import '../../../utility/constants.dart';
import 'ssh_key_management_form_dialog.dart';

class SshKeyPairBarActions extends ConsumerStatefulWidget {
  const SshKeyPairBarActions({required this.identifier, Key? key}) : super(key: key);

  final String identifier;

  @override
  ConsumerState<SshKeyPairBarActions> createState() => _SshKeyPairBarActionsState();
}

class _SshKeyPairBarActionsState extends ConsumerState<SshKeyPairBarActions> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(atSSHKeyPairManagerFamilyController(widget.identifier).notifier);
    return Row(
      children: [
        IconButton(
          style: FilledButton.styleFrom(backgroundColor: kIconColorBackgroundDark),
          onPressed: () async {
            await showDialog(
                context: context,
                builder: ((context) => SSHKeyManagementFormDialog(
                      identifier: widget.identifier,
                    )));
          },
          icon: const Icon(
            Icons.edit_outlined,
            color: Colors.white,
          ),
        ),
        gapW8,
        IconButton(
          style: FilledButton.styleFrom(backgroundColor: kIconColorBackgroundDark),
          onPressed: () {
            controller.deleteAtSSHKeyPairManager(identifier: widget.identifier);
          },
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.white,
          ),
        )
      ],
    );
  }
}
