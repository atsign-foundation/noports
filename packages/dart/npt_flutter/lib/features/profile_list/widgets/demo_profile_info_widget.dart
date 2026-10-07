import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../util/export.dart';

class DemoProfileInfoWidget extends StatelessWidget {
  const DemoProfileInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p16,
        vertical: Sizes.p10,
      ),
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: BoxDecoration(
        color: AppColor.primaryColorBackground,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColor.primaryColorButtonBackground,
              borderRadius: BorderRadius.circular(Sizes.p40),
            ),
            padding: const EdgeInsets.all(Sizes.p8),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.lightbulbFilament(),
                  color: AppColor.primaryColor,
                ),
                Text(
                  strings.demo,
                  style: const TextStyle(color: AppColor.primaryColor),
                ),
              ],
            ),
          ),
          gapW16,
          Text(
            strings.demoDescription,
            style: const TextStyle(color: Colors.black),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              // Show a progress indicator before fetching the demo profile
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );
              final String content;
              try {
                content = await Export.getDemoProfile();
              } catch (e) {
                App.log('Could not load the demo profile: $e'.loggable);
                CustomSnackBar.error(content: strings.profileImportFailed);
                return;
              } finally {
                navigator.pop(); // Dismiss the progress indicator
              }
              Export.convertExternalDataSourceToProfile(
                fileType: ExportableProfileFiletype.json,
                contents: content,
              );
            },
            child: Text(
              strings.demoTextButton,
              style: const TextStyle(
                color: AppColor.primaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
