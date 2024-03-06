import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../controllers/file_picker_controller.dart';
import '../../../controllers/private_key_manager_controller.dart';
import '../../../utility/constants.dart';
import 'ssh_key_management_form_dialog.dart';

class SshKeyPairBarActions extends ConsumerStatefulWidget {
  const SshKeyPairBarActions({required this.identifier, super.key});

  final String identifier;

  @override
  ConsumerState<SshKeyPairBarActions> createState() => _SshKeyPairBarActionsState();
}

class _SshKeyPairBarActionsState extends ConsumerState<SshKeyPairBarActions> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(privateKeyManagerFamilyController(widget.identifier).notifier);
    return Row(
      children: [
        IconButton(
          style: FilledButton.styleFrom(backgroundColor: kIconColorBackgroundDark),
          onPressed: () async {
            ref.read(filePickerController.notifier).clearFileDetails();
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
          onPressed: () async {
            await controller.deletePrivateKeyManager(identifier: widget.identifier);
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
