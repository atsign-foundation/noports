import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../util/export.dart';

class DemoProfileInfoWidget extends StatelessWidget {
  const DemoProfileInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p16, vertical: Sizes.p10),
      width: MediaQuery.of(context).size.width * 0.8,
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
            child: Row(children: [
              PhosphorIcon(
                PhosphorIcons.lightbulbFilament(),
                color: AppColor.primaryColor,
              ),
              Text(strings.demo,
                  style: const TextStyle(
                    color: AppColor.primaryColor,
                  ))
            ]),
          ),
          gapW16,
          Text(
            strings.demoDescription,
          ),
          TextButton(
            onPressed: () async {
              // Show a progress indicator before fetching the demo profile
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              final content = await Export.getDemoProfile();
              Navigator.of(context, rootNavigator: true).pop(); // Dismiss the progress indicator
              Export.convertExternalDataSourceToProfile(fileType: ExportableProfileFiletype.json, contents: content);
            },
            child: Text(
              strings.demoTextButton,
              style: const TextStyle(color: AppColor.primaryColor, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}
