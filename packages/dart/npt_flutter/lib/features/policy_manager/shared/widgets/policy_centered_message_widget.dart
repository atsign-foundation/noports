import 'package:flutter/material.dart';

class PolicyCenteredMessageWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? color;
  final double fontSize;

  const PolicyCenteredMessageWidget({
    super.key,
    required this.message,
    this.icon,
    this.color,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 64,
              color: color ?? Colors.grey,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}