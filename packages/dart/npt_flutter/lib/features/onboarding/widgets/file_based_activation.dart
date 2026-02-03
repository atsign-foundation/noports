import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
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
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width * 0.70;
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
        Text(
          strings.activationFileBased,
          style: Theme.of(
            context,
          ).textTheme.titleLarge!.copyWith(color: Colors.black),
        ),
        Text.rich(
          TextSpan(
            text: strings.activationFileBasedDescription,
            children: [
              TextSpan(
                text: strings.activationLinkText,
                recognizer: _tapRecognizer,
                style: const TextStyle(color: AppColor.primaryColor),
              ),
            ],
          ),
        ),
        GestureDetector(
          child: DropTarget(
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
                  borderRadius: BorderRadius.circular(Sizes.p8),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(strings.activationFileUploadDescription),
                    Text(strings.activationDragDropDescription),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
