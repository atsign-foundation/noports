import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';

class ProfileViewMinimal extends StatelessWidget {
  const ProfileViewMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Display name, favorite, and menu
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
          // Bottom row: Status and run button
          Row(
            children: [
              const SizedBox(width: 32), // Indent to align with name
              Expanded(child: ProfileStatusIndicator(width: double.infinity)),
              const SizedBox(width: 8),
              const ProfileRunButton(),
            ],
          ),
        ],
      ),
    );
  }
}
