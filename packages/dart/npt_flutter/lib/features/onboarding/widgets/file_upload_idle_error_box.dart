import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';

class FileUploadIdleErrorBox extends StatelessWidget {
  /// A widget which shows the idle and error states of the file upload process, displaying an error message and the name of the uploaded file when the file upload is in an idle or error state, and allows the user to click on it to re-upload the file.
  const FileUploadIdleErrorBox({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    bool errorStatus(MultiActivationFileUploadState state) {
      return state == MultiActivationFileUploadState.error;
    }

    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<MultiActivationCubit, MultiActivationState>(
      builder: (context, state) {
        return Container(
          padding: errorStatus(state.uploadState)
              ? const EdgeInsets.all(Sizes.p20)
              : null,

          decoration: errorStatus(state.uploadState)
              ? BoxDecoration(
                  color: AppColor.errorColorAlt,
                  borderRadius: BorderRadius.circular(Sizes.p8),
                  border: Border.all(color: AppColor.errorColor),
                )
              : null,
          child: Column(
            spacing: Sizes.p14,
            children: [
              errorStatus(state.uploadState)
                  ? Padding(
                      padding: const EdgeInsets.only(left: Sizes.p10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.activationFileErrorMessage,
                            style: const TextStyle(color: AppColor.errorColor),
                          ),
                          Text(state.fileContent.fileName),
                        ],
                      ),
                    )
                  : gap0,
              GestureDetector(
                onTap: () async =>
                    context.read<MultiActivationCubit>().getFilePickerPath(),
                child: DropTarget(
                  onDragDone: (details) {
                    context.read<MultiActivationCubit>().getDragAndDropPath(
                      details,
                    );
                  },
                  child: DottedBorder(
                    options: const RoundedRectDottedBorderOptions(
                      radius: Radius.circular(Sizes.p8),
                      dashPattern: [6, 4],
                      strokeCap: StrokeCap.round,
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(left: Sizes.p10),
                      width: width,

                      height: Sizes.p80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Sizes.p8),
                      ),

                      child: Align(
                        child: Text(
                          strings.activationFileUploadDragDropDescription,
                          // textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
