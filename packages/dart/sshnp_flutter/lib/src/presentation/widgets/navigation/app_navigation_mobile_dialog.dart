import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sshnp_flutter/src/presentation/widgets/navigation/navigation_list_tile.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

class AppNavigationMobileDialog extends StatelessWidget {
  const AppNavigationMobileDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topLeft,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: Sizes.p247,
            height: Sizes.p103,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p20),
              ),
              color: kBackGroundColorDark,
              child: Padding(
                padding: const EdgeInsets.all(Sizes.p24),
                child: SvgPicture.asset('assets/images/noports_light.svg'),
              ),
            ),
          ),
          gapH16,
          SizedBox(
            width: Sizes.p247,
            height: Sizes.p286,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p20),
              ),
              color: kBackGroundColorDark,
              child: const Column(
                children: [
                  NavigationListTile.currentConnections(),
                  Divider(
                    color: Colors.white24,
                  ),
                  NavigationListTile.terminal(),
                  Divider(
                    color: Colors.white24,
                  ),
                  NavigationListTile.support(),
                  Divider(
                    color: Colors.white24,
                  ),
                  NavigationListTile.settings(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
