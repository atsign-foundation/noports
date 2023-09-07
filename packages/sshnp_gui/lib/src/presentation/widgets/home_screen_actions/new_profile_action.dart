import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/minor_providers.dart';
import 'package:sshnp_gui/src/controllers/sshnp_config_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

class NewProfileAction extends ConsumerStatefulWidget {
  const NewProfileAction({Key? key}) : super(key: key);

  @override
  ConsumerState<NewProfileAction> createState() => _NewProfileActionState();
}

class _NewProfileActionState extends ConsumerState<NewProfileAction> {
  void onPressed() {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(currentParamsController.notifier).setState(
          CurrentSSHNPParamsModel(
            profileName: '',
            configFileWriteState: ConfigFileWriteState.create,
          ),
        );
    // change value to 1 to update navigation rail selcted icon.
    ref.watch(currentNavIndexProvider.notifier).update((_) => AppRoute.profileForm.index - 1);
    context.replaceNamed(
      AppRoute.profileForm.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        onPressed();
      },
      icon: const Icon(Icons.add),
    );
  }
}
