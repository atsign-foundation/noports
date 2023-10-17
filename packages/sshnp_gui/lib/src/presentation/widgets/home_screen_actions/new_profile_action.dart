import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';

class NewProfileAction extends ConsumerStatefulWidget {
  const NewProfileAction({Key? key}) : super(key: key);

  @override
  ConsumerState<NewProfileAction> createState() => _NewProfileActionState();
}

class _NewProfileActionState extends ConsumerState<NewProfileAction> {
  void onPressed() {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(currentConfigController.notifier).setState(
          CurrentConfigState(
            profileName: '',
            configFileWriteState: ConfigFileWriteState.create,
          ),
        );
    context.replaceNamed(
      AppRoute.profileForm.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        onPressed();
      },
      child: const Icon(Icons.add_circle_outline),
    );
  }
}
