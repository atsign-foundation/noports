import 'package:flutter/material.dart';

class PolicySectionHeaderWidget extends StatelessWidget {
  final String title;
  final double fontSize;
  final FontWeight fontWeight;
  final Widget? action;

  const PolicySectionHeaderWidget({
    super.key,
    required this.title,
    this.fontSize = 18,
    this.fontWeight = FontWeight.bold,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
        if (action != null) ...[
          const Spacer(),
          action!,
        ],
      ],
    );
  }
}