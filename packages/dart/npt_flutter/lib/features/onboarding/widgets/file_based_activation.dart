import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/multi_activation_file_content.dart';
import 'package:npt_flutter/features/onboarding/widgets/file_upload_idle_error_box.dart';
import 'package:npt_flutter/features/onboarding/widgets/file_upload_loading_success_box.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FileBasedActivation extends StatefulWidget {
  const FileBasedActivation({super.key});

  @override
  State<FileBasedActivation> createState() => _FileBasedActivationState();
}

class _FileBasedActivationState extends State<FileBasedActivation> {
  late TapGestureRecognizer _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final Uri url = Uri.parse('https://my.noports.com/no-ports-plans/');
        if (!await launchUrl(url)) {
          throw Exception('Could not launch $url');
        }
      };
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Sizes.p10,
      children: [
        Text(
          strings.activationComplete,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall!.copyWith(color: Colors.black),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.activationFileBased,
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(color: Colors.black),
            ),
            Chip(
              avatar: PhosphorIcon(
                PhosphorIcons.lightning(),
                color: AppColor.primaryColor,
              ),
              label: Text(strings.fastest),
              labelStyle: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: AppColor.primaryColor),
              backgroundColor: AppColor.primaryColorBackground,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(Sizes.p24),
              ),
            ),
          ],
        ),
        Text(strings.activationFileBasedDescription),
        BlocSelector<
          MultiActivationCubit,
          MultiActivationState,
          MultiActivationFileUploadState
        >(
          selector: (state) => state.uploadState,
          builder: (context, state) {
            return state == MultiActivationFileUploadState.error ||
                    state == MultiActivationFileUploadState.idle
                ? FileUploadIdleErrorBox(width: width)
                : FileUploadLoadSuccessBox(width: width);
          },
        ),

        BlocSelector<
          MultiActivationCubit,
          MultiActivationState,
          MultiActivationFileContent
        >(
          selector: (state) => state.fileContent,
          builder: (context, state) {
            return state.entries.isEmpty
                ? gap0
                : Column(
                    children: [
                      const Divider(color: AppColor.dividerColorAlt),
                      Text(strings.activationAtsignListDescription),
                      gapH10,
                      SizedBox(
                        height: Sizes.p96,
                        child: SingleChildScrollView(
                          child: Column(
                            spacing: Sizes.p10,
                            children: [
                              ...state.entries.map(
                                (entry) => Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.only(
                                    left: Sizes.p10,
                                    top: Sizes.p10,
                                    bottom: Sizes.p10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColor.dividerColorAlt,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      Sizes.p8,
                                    ),
                                  ),
                                  child: Text(entry.atsign),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }
}
