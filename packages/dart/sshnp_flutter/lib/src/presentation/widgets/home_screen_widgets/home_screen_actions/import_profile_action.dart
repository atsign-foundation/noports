import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import 'home_screen_action_callbacks.dart';

class ImportProfileAction extends ConsumerStatefulWidget {
  const ImportProfileAction({super.key});

  @override
  ConsumerState<ImportProfileAction> createState() => _ImportProfileActionState();
}

class _ImportProfileActionState extends ConsumerState<ImportProfileAction> {
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: Theme.of(context).filledButtonTheme.style!.copyWith(
            backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
            foregroundColor: WidgetStateProperty.all<Color>(kPrimaryColor),
          ),
      onPressed: () {
        HomeScreenActionCallbacks.import(ref, context);
      },
      child: const Icon(Icons.file_upload_outlined),
    );
  }
}
