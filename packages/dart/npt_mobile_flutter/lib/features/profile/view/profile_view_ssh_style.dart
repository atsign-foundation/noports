import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 700;

        if (isMobile) {
          // Mobile-friendly stacked layout
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Checkbox, Display name, Actions
                Row(
                  children: [
                    const ProfileSelectBox(),
                    const SizedBox(width: 8),
                    Expanded(child: ProfileDisplayName(width: double.infinity)),
                    const SizedBox(width: 8),
                    const ProfileFavoriteButton(),
                    const SizedBox(width: 4),
                    const ProfilePopupMenuButton(),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Device name
                Row(
                  children: [
                    const SizedBox(width: 32), // Align with name above
                    Expanded(child: ProfileDeviceName(width: double.infinity)),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 3: IP/Ports
                Row(
                  children: [
                    const SizedBox(width: 32), // Align with name above
                    Expanded(child: ProfileServiceView(width: double.infinity)),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 4: Status and Run button
                Row(
                  children: [
                    const SizedBox(width: 32), // Align with name above
                    Expanded(
                      child: ProfileStatusIndicator(width: double.infinity),
                    ),
                    const SizedBox(width: 8),
                    const ProfileRunButton(),
                  ],
                ),
              ],
            ),
          );
        }

        // Desktop/tablet horizontal layout
        final width = SizeConfig.setProfileFieldWidth();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProfileSelectBox(),
            gapW10,
            ProfileDisplayName(width: width),
            gapW10,
            ProfileDeviceName(width: width),
            gapW10,
            ProfileServiceView(width: width),
            gapW10,
            ProfileStatusIndicator(
              width: SizeConfig.setProfileFieldWidth(statusField: true),
            ),
            gapW10,
            const Flexible(child: ProfileRunButton()),
            gapW10,
            const Flexible(child: ProfileFavoriteButton()),
            gapW10,
            const Flexible(child: ProfilePopupMenuButton()),
            gapW10,
          ],
        );
      },
    );
  }
}
