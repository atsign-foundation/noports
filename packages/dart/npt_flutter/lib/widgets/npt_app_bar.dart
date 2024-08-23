import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';

import '../styles/sizes.dart';

class NptAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? settingsSelectedColor;

  const NptAppBar({
    super.key,
    required this.title,
    this.settingsSelectedColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.p100);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            color: AppColor.dividerColor,
            height: Sizes.p38,
            width: Sizes.p2,
          ),
          gapW20,
          Text(
            title,
          ),
        ],
      ),
      actions: [
        IconButton(
          color: settingsSelectedColor,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
      centerTitle: false,
      elevation: 4.0,
    );
  }
}
