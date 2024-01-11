import 'package:flutter/material.dart';

import 'app_navigation_mobile_dialog.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: ((context) => const AppNavigationMobileDialog()),
            );
          },
          icon: const Icon(Icons.menu)),
      title: title,
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
