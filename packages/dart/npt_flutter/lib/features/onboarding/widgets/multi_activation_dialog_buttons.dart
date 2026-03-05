import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/widgets/backup_key_alert_dialog.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';
import 'package:npt_flutter/features/onboarding/widgets/activation_dialog_final.dart';
import 'package:npt_flutter/features/onboarding/widgets/get_started_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

class MultiActivationDialogButtons extends StatelessWidget {
  const MultiActivationDialogButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;
    return BlocSelector<
      MultiActivationCubit,
      MultiActivationState,
      MultiActivationFileContent
    >(
      selector: (state) => state.fileContent,
      builder: (context, state) {
        return SizedBox(
          width: width,
          child: Row(
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  context.read<MultiActivationCubit>().reset();
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) => const GetStartedDialog(),
                  );
                },
                child: Text(strings.cancel),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: state.entries.isNotEmpty
                    ? () async {
                        // Show the back up dialog so user understands the importance of backing up their atKeys.
                        await showAdaptiveDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (context) =>
                              const BackupKeyAlertDialog(isBackup: false),
                        );

                        Navigator.of(App.navState.currentContext!).pop();
                        App.navState.currentContext!
                            .read<MultiActivationCubit>()
                            .activateAll();
                        await showAdaptiveDialog(
                          barrierDismissible: false,
                          context: App.navState.currentContext!,
                          builder: (context) => const ActivationDialogFinal(),
                        );
                      }
                    : null,
                child: Text(strings.next),
              ),
            ],
          ),
        );
      },
    );
  }
}
