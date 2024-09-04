import 'package:flutter/material.dart';
import 'package:npt_flutter/styles/app_color.dart';

import '../../../styles/sizes.dart';

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 60,
      decoration: BoxDecoration(color: AppColor.primaryColor, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.p12),
        child: ListTile(
          leading: Icon(
            icon,
            color: Colors.white,
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 18, color: Colors.white),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
