import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:npt_flutter/styles/style_constants.dart';

import '../styles/sizes.dart';

class NptAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? settingsSelectedColor;
  final bool isNavigateBack;
  final bool showSettings;

  const NptAppBar({
    super.key,
    this.title = '',
    this.settingsSelectedColor,
    this.isNavigateBack = true,
    this.showSettings = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(isNavigateBack ? Sizes.p150 : Sizes.p100);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AppBar(
      titleSpacing: 0,
      leading: gap0,
      toolbarHeight: isNavigateBack ? Sizes.p150 : Sizes.p100,
      title: Row(
        children: [
          Column(
            children: [
              gapH16,
              SvgPicture.asset(
                'assets/noports_logo.svg',
                height: Sizes.p54,
                width: Sizes.p175,
              ),
              gapH16,
              isNavigateBack
                  ? TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      label: Text(
                        strings.back,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                      ),
                      style: StyleConstants.backButtonStyle,
                    )
                  : gap0,
            ],
          ),
          gapW27,
          Column(
            children: [
              Container(
                color: AppColor.dividerColor,
                height: Sizes.p38,
                width: Sizes.p2,
              ),
              gapH25
            ],
          ),
          gapW20,
          Column(
            children: [
              Text(
                title,
              ),
              gapH25,
            ],
          ),
        ],
      ),
      actions: [
        showSettings
            ? IconButton(
                padding: const EdgeInsets.only(bottom: Sizes.p30),
                color: settingsSelectedColor,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              )
            : gap0,
      ],
      centerTitle: true,
    );
  }
}
