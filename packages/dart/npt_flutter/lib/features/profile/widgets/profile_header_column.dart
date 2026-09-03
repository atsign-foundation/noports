import 'package:flutter/material.dart';

class ProfileHeaderColumn extends StatelessWidget {
  const ProfileHeaderColumn({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}
