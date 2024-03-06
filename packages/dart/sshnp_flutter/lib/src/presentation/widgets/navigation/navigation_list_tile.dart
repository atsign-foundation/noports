import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../utility/sizes.dart';

class NavigationListTile extends StatelessWidget {
  const NavigationListTile({
    super.key,
    required this.iconData,
    required this.title,
    required this.type,
    required this.tileColor,
  });

  const NavigationListTile.currentConnections(
      {this.iconData = Icons.power_settings_new_outlined,
      this.title = 'Current\nConnections',
      this.type = CustomListTileType.currentConnections,
      this.tileColor = kBackGroundColorDark,
      super.key});
  const NavigationListTile.terminal({
    this.iconData = Icons.terminal_outlined,
    this.title = 'Terminal',
    this.type = CustomListTileType.terminal,
    this.tileColor = kBackGroundColorDark,
    super.key,
  });
  const NavigationListTile.support({
    this.iconData = Icons.question_mark_outlined,
    this.title = 'Support',
    this.type = CustomListTileType.support,
    this.tileColor = kBackGroundColorDark,
    super.key,
  });
  const NavigationListTile.settings({
    this.iconData = Icons.settings,
    this.title = 'Settings',
    this.type = CustomListTileType.settings,
    this.tileColor = kBackGroundColorDark,
    super.key,
  });

  final IconData iconData;
  final String title;

  final CustomListTileType type;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    Future<void> onTap() async {
      switch (type) {
        case CustomListTileType.currentConnections:
          context.goNamed(AppRoute.home.name);
          break;
        case CustomListTileType.terminal:
          context.goNamed(AppRoute.terminal.name);
          break;
        case CustomListTileType.support:
          context.goNamed(AppRoute.support.name);
          break;
        case CustomListTileType.settings:
          context.goNamed(AppRoute.settings.name);
          break;
      }
    }

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.p20),
      ),
      leading: Icon(
        iconData,
      ),
      title: Text(title),
      onTap: () async {
        await onTap();
      },
      tileColor: tileColor,
    );
  }
}

enum CustomListTileType {
  currentConnections,
  terminal,
  support,
  settings,
}
