import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/widgets/file_based_activation.dart';
import 'package:npt_flutter/features/onboarding/widgets/manual_activation.dart';
import 'package:npt_flutter/features/onboarding/widgets/manual_activation_dialog_buttons.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/or_divider.dart';

import 'multi_activation_dialog_buttons.dart';

class ActivationDialogInitial extends StatelessWidget {
  /// A dialog which allows the user to complete activation using a file based flow or a manual entry flow.
  const ActivationDialogInitial({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.p20),
          child:
              BlocSelector<
                MultiActivationCubit,
                MultiActivationState,
                MultiActivationFileUploadState
              >(
                selector: (state) => state.uploadState,
                builder: (context, state) {
                  return Column(
                    spacing: Sizes.p10,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FileBasedActivation(),
                      gapH4,

                      if (state != MultiActivationFileUploadState.success) ...[
                        const OrDivider(),
                        const ManualActivation(),
                      ],
                      const Divider(color: AppColor.dividerColorAlt),
                      state == MultiActivationFileUploadState.idle
                          ? const ManualActivationDialogButtons()
                          : const MultiActivationDialogButtons(),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
