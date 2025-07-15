import 'package:flutter/material.dart';

class PolicyCardWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;

  const PolicyCardWidget({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderRadius = 8,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}