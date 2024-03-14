import 'package:flutter/material.dart';

class ProfileActionButton extends StatelessWidget {
  final void Function() onPressed;
  final Widget icon;
  const ProfileActionButton({
    required this.onPressed,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
    );
  }
}
