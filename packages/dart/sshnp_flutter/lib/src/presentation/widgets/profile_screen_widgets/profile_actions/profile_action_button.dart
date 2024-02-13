import 'package:flutter/material.dart';

class ProfileActionButton extends StatelessWidget {
  final void Function() onPressed;
  final Widget icon;
  const ProfileActionButton({
    required this.onPressed,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
    );
  }
}
