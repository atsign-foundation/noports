import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class FileUploadLoadSuccessBox extends StatelessWidget {
  /// A widget which shows the loading and success states of the file upload process, displaying a success message and the name of the uploaded file when the file upload is in a success state, and a loading message when the file upload is in a loading state.
  const FileUploadLoadSuccessBox({super.key, required this.width});

  final double width;

  bool successStatus(MultiActivationFileUploadState state) =>
      state == MultiActivationFileUploadState.success;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<MultiActivationCubit, MultiActivationState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(Sizes.p20),

          decoration: successStatus(state.uploadState)
              ? BoxDecoration(
                  color: AppColor.successColorAlt,
                  borderRadius: BorderRadius.circular(Sizes.p8),
                )
              : BoxDecoration(
                  color: AppColor.loadingColorAlt,
                  borderRadius: BorderRadius.circular(Sizes.p8),
                ),
          child: Column(
            spacing: Sizes.p14,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Sizes.p10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: successStatus(state.uploadState)
                      ? [
                          Text(
                            strings.activationFileSuccessMessage,
                            style: const TextStyle(
                              color: AppColor.onSurfaceColorAlt,
                            ),
                          ),
                          PhosphorIcon(
                            PhosphorIcons.sealCheck(),
                            color: AppColor.successColor,
                          ),
                        ]
                      : [
                          Text(
                            strings.activationFileLoadingMessage,
                            style: const TextStyle(
                              color: AppColor.primaryColor,
                            ),
                          ),
                          PhosphorIcon(
                            PhosphorIcons.circleDashed(),
                            color: AppColor.primaryColor,
                          ),
                        ],
                ),
              ),

              Container(
                padding: const EdgeInsets.only(
                  left: Sizes.p10,
                  right: Sizes.p10,
                ),
                width: width,

                height: Sizes.p80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Sizes.p8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(state.fileContent.fileName),
                    successStatus(state.uploadState)
                        ? IconButton(
                            onPressed: () =>
                                context.read<MultiActivationCubit>().reset(),

                            icon: PhosphorIcon(PhosphorIcons.trash()),
                          )
                        : gap0,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
