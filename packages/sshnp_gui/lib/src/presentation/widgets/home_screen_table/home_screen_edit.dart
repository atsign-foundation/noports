import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

class HomeScreenEditAction extends ConsumerStatefulWidget {
  final SSHNPParams params;
  const HomeScreenEditAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreenEditAction> createState() =>
      _HomeScreenEditActionState();
}

class _HomeScreenEditActionState extends ConsumerState<HomeScreenEditAction> {
  void updateConfigFile(SSHNPParams params) {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(currentParamsController.notifier).setState(
          CurrentSSHNPParamsModel(
            profileName: params.profileName!,
            configFileWriteState: ConfigFileWriteState.update,
          ),
        );
    // change value to 1 to update navigation rail selcted icon.
    ref
        .watch(currentNavIndexProvider.notifier)
        .update((_) => AppRoute.newConnection.index - 1);
    context.replaceNamed(
      AppRoute.newConnection.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        updateConfigFile(widget.params);
      },
      icon: const Icon(Icons.edit),
    );
  }
}
