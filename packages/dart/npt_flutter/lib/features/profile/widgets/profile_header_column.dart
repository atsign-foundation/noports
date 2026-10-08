import 'package:flutter/material.dart';

class ProfileHeaderColumn extends StatelessWidget {
  const ProfileHeaderColumn({
    super.key,
    required this.title,
    this.width,
  });

  final String title;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis,
    );
    if (width != null) {
      return SizedBox(width: width, child: text);
    }
    return text;
  }
}
