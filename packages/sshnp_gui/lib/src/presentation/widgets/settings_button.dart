import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/utils/constants.dart';

import '../../utils/sizes.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({
    required this.icon,
    required this.title,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 60,
      decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.p12),
        child: ListTile(
          leading: Icon(
            icon,
            color: Colors.white,
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 18, color: Colors.white),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
