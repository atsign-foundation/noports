import 'package:flutter/material.dart';

import '../../../../utility/sizes.dart';

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
    SizeConfig().init(context);
    return IconButton(
      iconSize: 24.toFont,
      onPressed: onPressed,
      icon: icon,
    );
  }
}
