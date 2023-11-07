import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';

class SSHKeyManagementAction extends ConsumerStatefulWidget {
  const SSHKeyManagementAction({Key? key}) : super(key: key);

  @override
  ConsumerState<SSHKeyManagementAction> createState() => _SSHKeyManagementActionState();
}

class _SSHKeyManagementActionState extends ConsumerState<SSHKeyManagementAction> {
  void onPressed() {
    // Change value to update to trigger the update functionality on the new connection form.
    // ref.watch(currentConfigController.notifier).setState(
    //       CurrentConfigState(
    //         profileName: '',
    //         configFileWriteState: ConfigFileWriteState.create,
    //       ),
    //     );
    context.replaceNamed(
      AppRoute.sshKeyManagement.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        onPressed();
      },
      child: const Icon(
        Icons.key_outlined,
      ),
    );
  }
}
