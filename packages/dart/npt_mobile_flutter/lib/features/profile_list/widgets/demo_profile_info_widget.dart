import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../util/export.dart';

class DemoProfileInfoWidget extends StatelessWidget {
  const DemoProfileInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.p16,
        vertical: Sizes.p10,
      ),
      width: isMobile ? screenWidth * 0.95 : screenWidth * 0.75,
      decoration: BoxDecoration(
        color: AppColor.primaryColorBackground,
        borderRadius: BorderRadius.circular(Sizes.p10),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColor.primaryColorButtonBackground,
                    borderRadius: BorderRadius.circular(Sizes.p40),
                  ),
                  padding: const EdgeInsets.all(Sizes.p8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.lightbulbFilament(),
                        color: AppColor.primaryColor,
                      ),
                      gapW4,
                      Text(
                        strings.demo,
                        style: const TextStyle(color: AppColor.primaryColor),
                      ),
                    ],
                  ),
                ),
                gapH8,
                Text(
                  strings.demoDescription,
                  style: const TextStyle(color: Colors.black),
                ),
                gapH4,
                TextButton(
                  onPressed: () async {
                    // Show a progress indicator before fetching the demo profile
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    final content = await Export.getDemoProfile();
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(); // Dismiss the progress indicator
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
            )
          : Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColor.primaryColorButtonBackground,
                    borderRadius: BorderRadius.circular(Sizes.p40),
                  ),
                  padding: const EdgeInsets.all(Sizes.p8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.lightbulbFilament(),
                        color: AppColor.primaryColor,
                      ),
                      gapW4,
                      Text(
                        strings.demo,
                        style: const TextStyle(color: AppColor.primaryColor),
                      ),
                    ],
                  ),
                ),
                gapW12,
                Expanded(
                  child: Text(
                    strings.demoDescription,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Show a progress indicator before fetching the demo profile
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    final content = await Export.getDemoProfile();
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(); // Dismiss the progress indicator
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
