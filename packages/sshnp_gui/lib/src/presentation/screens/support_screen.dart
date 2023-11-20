import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_gui/src/presentation/widgets/custom_list_tile.dart';
import 'package:sshnp_gui/src/presentation/widgets/navigation/app_navigation_rail.dart';
import 'package:sshnp_gui/src/utility/constants.dart';
import 'package:sshnp_gui/src/utility/sizes.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);
  static String route = 'supportScreen';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.p36, top: Sizes.p21),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Sizes.p20),
                    child: Text(
                      strings.support,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Text(
                    strings.supportDescription,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: kTextColorDark),
                  ),
                  gapH30,
                  CustomListTile.discord(
                    onTap: () async {
                      {
                        final Uri url = Uri.parse('https://discord.gg/atsign-778383211214536722');
                        if (!await launchUrl(url)) {
                          throw Exception('Could not launch $url');
                        }
                      }
                    },
                  ),
                  CustomListTile.email(
                    onTap: () async {
                      Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'atDataBrowser@atsign.com',
                      );
                      if (!await launchUrl(emailUri)) {
                        throw Exception('Could not launch $emailUri');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}
